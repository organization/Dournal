module config;

struct MongoDB {
    string host;
    string databaseName;
}

struct Google {
    string clientId;
    string clientSecret;
}

struct Github {
    string clientId;
    string clientSecret;
}

struct Config {
    ushort port;
    string ipv4Address;
    string ipv6Address;

    MongoDB mongoDB;

    Google googleOAuth;
    Github githubOAuth;
}
