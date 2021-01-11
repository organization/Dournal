module router;

import config;
import dlogg.log;
import dlogg.strict;
import vibe.d;
import authorization.oauth;

class Router {
    private auto urlRouter = new URLRouter();
    private auto httpServerSettings = new HTTPServerSettings();
    private OAuth oauth;
    private shared StrictLogger logger;
    private Config config;

    this(shared StrictLogger logger, Config config) {
        this.logger = logger;
        this.config = config;

        this.httpServerSettings.port = config.port;
        this.httpServerSettings.bindAddresses = [config.ipv4Address, config.ipv6Address];
        this.httpServerSettings.sessionStore = new MemorySessionStore();

        this.oauth = new OAuth(config);
    }

    void run() {
        this.urlRouter.get("/api/user/logout", (HTTPServerRequest req, HTTPServerResponse res) {
            res.terminateSession();
            res.redirect("/");
        });

        oauth.registerOAuth(this.urlRouter);

        import vibe.db.mongo.mongo : connectMongoDB;
        import database.users : UserController, users, User;

        auto database = connectMongoDB(this.config.mongoDB.host).getDatabase(this.config.mongoDB.databaseName);
        users = new UserController(database);

        listenHTTP(this.httpServerSettings, this.urlRouter);
    }
}
