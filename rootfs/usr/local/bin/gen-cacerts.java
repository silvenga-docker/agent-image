import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.security.KeyStore;
import java.security.cert.CertificateFactory;

/// Generates a Java trust store (JKS) from all PEM CA certificates in /etc/ssl/certs/.
/// Uses JKS (not PKCS12) because Java's default truststore loading does not reliably
/// detect PKCS12 for the cacerts file — sdkmanager fails with
/// "trustAnchors parameter must be non-empty" on PKCS12 truststores.
/// Single JVM invocation — far faster than spawning keytool per certificate.
class gen_cacerts {
    public static void main(String[] args) throws Exception {
        var storepass = "changeit".toCharArray();
        var ks = KeyStore.getInstance("JKS");
        ks.load(null, storepass);

        var cf = CertificateFactory.getInstance("X.509");
        var dir = new File("/etc/ssl/certs");
        var pems = dir.listFiles((d, n) -> n.endsWith(".pem"));
        if (pems == null) pems = new File[0];

        int count = 0;
        for (var pem : pems) {
            try (var is = new FileInputStream(pem)) {
                var cert = cf.generateCertificate(is);
                var alias = pem.getName().replace(".pem", "")
                        .replaceAll("[^A-Za-z0-9._-]", "_");
                if (alias.length() > 60) alias = alias.substring(0, 60);
                if (!ks.containsAlias(alias)) {
                    ks.setCertificateEntry(alias, cert);
                    count++;
                }
            } catch (Exception e) {
                // skip unreadable or invalid certs
            }
        }

        new File("/var/lib/java-cacerts").mkdirs();
        try (var fos = new FileOutputStream("/var/lib/java-cacerts/cacerts")) {
            ks.store(fos, storepass);
        }
        new File("/var/lib/java-cacerts/cacerts").setReadable(true, false);

        System.out.println("java-cacerts: generated keystore with " + count
                + " CA certificates at /var/lib/java-cacerts/cacerts");
    }
}