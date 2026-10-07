/**
 * @description HTTP Callout Mock for simulating external server 500 errors.
 */
@isTest
public class SmartResolveCalloutFailureMock implements HttpCalloutMock {
    
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(500);
        res.setStatus('Internal Server Error');
        res.setBody('{"error":"Gateway Timeout or Downstream Service Unreachable"}');
        return res;
    }
}
