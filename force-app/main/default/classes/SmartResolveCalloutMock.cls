/**
 * @description HTTP Callout Mock for simulating external ERP, Payment, and Logistics responses.
 */
@isTest
public class SmartResolveCalloutMock implements HttpCalloutMock {
    
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);

        String endpoint = req.getEndpoint();
        if (endpoint.contains('orders') || endpoint.contains('erp')) {
            res.setBody('{"orderNumber":"ORD-89241","orderStatus":"Delivered","warrantyStatus":"Active","item":"Smart Refrigerator"}');
        } else if (endpoint.contains('payment') || endpoint.contains('transactions')) {
            res.setBody('{"transactionId":"TXN-77312","paymentStatus":"Paid","amount":1249.99,"method":"Visa"}');
        } else if (endpoint.contains('logistics') || endpoint.contains('shipments')) {
            res.setBody('{"trackingNumber":"TRK-992144","deliveryStatus":"Completed","carrier":"Apex Logistics","deliveredOn":"2026-09-28"}');
        } else {
            res.setBody('{"status":"Success","message":"Operation verified"}');
        }
        return res;
    }
}
