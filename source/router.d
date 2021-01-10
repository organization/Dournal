module router;

import config;
import dlogg.log;
import dlogg.strict;
import vibe.d;

class Router {
    private auto urlRouter = new URLRouter();
    private auto httpServerSettings = new HTTPServerSettings();
    private shared StrictLogger logger;
    private Config config;

    this(shared StrictLogger logger, Config config) {
        this.logger = logger;
        this.config = config;
    }

    void run() {
        listenHTTP(this.httpServerSettings, this.urlRouter);
    }
}
