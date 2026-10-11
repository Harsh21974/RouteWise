package com.routewise.service;

import com.routewise.api.dto.DeliveryDto;
import com.routewise.api.dto.DeliveryIntakeResponse;
import com.routewise.api.dto.ManualDeliveryRequest;
import com.routewise.api.dto.ParsedAddress;
import com.routewise.error.BadRequestException;
import com.routewise.error.NotFoundException;
import com.routewise.model.Delivery;
import com.routewise.model.DeliveryStatus;
import com.routewise.model.GeocodeStatus;
import com.routewise.model.Order;
import com.routewise.repository.DeliveryRepository;
import com.routewise.repository.OrderRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Parcel intake: captures an arriving parcel from a barcode scan, an OCR pass
 * over a label photo, or a manually typed address.
 *
 * <p>Intake only produces parcels; geocoding and routing are separate. OCR and
 * manual intake therefore create deliveries with {@code NOT_GEOCODED}
 * coordinates (null), which are rejected by the optimization pipeline until a
 * geocoder fills them in. The optimization pipeline is not touched here.
 */
@Service
public class DeliveryIntakeService {

    private static final String SOURCE_SCAN = "SCAN";
    private static final String SOURCE_OCR = "OCR";
    private static final String SOURCE_MANUAL = "MANUAL";

    private final DeliveryRepository deliveryRepository;
    private final OrderRepository orderRepository;

    public DeliveryIntakeService(
            DeliveryRepository deliveryRepository, OrderRepository orderRepository) {
        this.deliveryRepository = deliveryRepository;
        this.orderRepository = orderRepository;
    }

    /**
     * Barcode/QR intake. Looks the scanned order up in the orders table; when
     * found, address + coordinates are taken from it directly. A 404 is
     * thrown (so the client can fall back to OCR or manual entry) when the
     * order is unknown.
     */
    @Transactional
    public DeliveryIntakeResponse scan(String orderId) {
        Order order = orderRepository.findByOrderId(orderId)
                .orElseThrow(() -> new NotFoundException(
                        "Order " + orderId + " not found. Fall back to OCR or manual entry."));

        Delivery delivery = new Delivery();
        delivery.setOrderId(order.getOrderId());
        delivery.setRawAddress(order.getRawAddress());
        delivery.setLatitude(order.getLatitude());
        delivery.setLongitude(order.getLongitude());
        delivery.setStatus(DeliveryStatus.PENDING);
        delivery.setGeocodeStatus(order.hasCoordinates()
                ? GeocodeStatus.GEOCODED
                : GeocodeStatus.NOT_GEOCODED);
        delivery = deliveryRepository.save(delivery);
        return new DeliveryIntakeResponse(DeliveryDto.from(delivery), SOURCE_SCAN, null);
    }

    /**
     * OCR intake. Parses raw label text into a best-effort structured address
     * and stores it (un-geocoded). The raw text is kept when nothing could be
     * parsed. {@code orderId} is optional.
     */
    @Transactional
    public DeliveryIntakeResponse ocr(String rawText, String orderId) {
        ParsedAddress parsed = AddressParser.parse(rawText);
        String address = parsed.displayText() != null ? parsed.displayText() : rawText.trim();

        Delivery delivery = new Delivery();
        delivery.setOrderId(trimToNull(orderId));
        delivery.setRawAddress(address);
        delivery.setStatus(DeliveryStatus.PENDING);
        delivery.setGeocodeStatus(GeocodeStatus.NOT_GEOCODED);
        delivery = deliveryRepository.save(delivery);
        return new DeliveryIntakeResponse(DeliveryDto.from(delivery), SOURCE_OCR, parsed);
    }

    /**
     * Manual intake. Same outcome as OCR intake, but from a typed structured
     * address instead of parsed text.
     */
    @Transactional
    public DeliveryIntakeResponse manual(ManualDeliveryRequest request) {
        String street = trimToNull(request.street());
        String area = trimToNull(request.area());
        String city = trimToNull(request.city());
        String pincode = trimToNull(request.pincode());
        if (street == null && area == null && city == null && pincode == null) {
            throw new BadRequestException("Provide at least one address field: street, area, city or pincode.");
        }

        ParsedAddress parsed = ParsedAddress.fromComponents(street, area, city, pincode);

        Delivery delivery = new Delivery();
        delivery.setOrderId(trimToNull(request.orderId()));
        delivery.setRawAddress(parsed.displayText());
        delivery.setStatus(DeliveryStatus.PENDING);
        delivery.setGeocodeStatus(GeocodeStatus.NOT_GEOCODED);
        delivery = deliveryRepository.save(delivery);
        return new DeliveryIntakeResponse(DeliveryDto.from(delivery), SOURCE_MANUAL, parsed);
    }

    private static String trimToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }
}