package megamekmobile.bridge;

import megamek.client.HeadlessClient;

/**
 * The bridge's single connection to the MegaMek server. Thin subclass of MegaMek's own
 * {@link HeadlessClient} (see docs/protocol-notes.md - this is the class PR #6418 added for exactly
 * this kind of non-GUI, programmatic use) kept around as a named extension point rather than using
 * {@code HeadlessClient} directly, in case the bridge ever needs to override client behaviour (it does
 * not yet).
 */
public class MegaMekBridgeClient extends HeadlessClient {

    public MegaMekBridgeClient(String name, String host, int port) {
        super(name, host, port);
    }
}
