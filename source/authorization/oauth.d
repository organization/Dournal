module authorization.oauth;

import oauth.settings : OAuthSettings;
import oauth.webapp : OAuthWebapp;

import vibe.http.router : URLRouter;
import vibe.http.client : requestHTTP;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.data.json : Json;

import config;

public class OAuth {
    private OAuthWebapp webapp;
    private immutable(OAuthSettings) googleOAuthSettings;
    private immutable(OAuthSettings) githubOAuthSettings;
    private string finalRedirectUri;

    this(Config config) {
        import oauth.provider.google : GoogleAuthSettings;
        import std.process : environment;

        webapp = new OAuthWebapp;

        // oauth stuff
        // TODO: make callback uri configureable
        googleOAuthSettings = new immutable(GoogleAuthSettings)("google", config.googleOAuth.clientId,
                config.googleOAuth.clientSecret, "http://localhost:8080/api/user/login/google");
        githubOAuthSettings = new immutable(OAuthSettings)("github", config.githubOAuth.clientId,
                config.githubOAuth.clientSecret, "http://localhost:8080/api/user/login/github");
        finalRedirectUri = "/";
    }

    string[] googleScopes = [
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile"
    ];

    string[] githubScopes = ["user:email"];

    import database.users : User, users;

    bool isLoggedIn(scope HTTPServerRequest req) @safe {
        if (!req.session)
            return false;

        if (req.session.isKeySet("user"))
            return true;

        return false;
    }

    void registerOAuth(scope URLRouter router) {
        router.get("/api/user/login/error", (req, res) {
            res.writeBody("An error happened");
        });

        router.get("/api/user/login/google", (req, res) @safe { // TODO: necessary?
            if (isLoggedIn(req)) {
                return res.redirect(finalRedirectUri);
            } else if (webapp.login(req, res, googleOAuthSettings, null, googleScopes)) {
                // TODO: oauth.session is fetched from session store (was set in webapp.login)
                auto session = webapp.oauthSession(req);
                requestHTTP("https://www.googleapis.com/userinfo/v2/me", (scope googleReq) {
                    session.authorizeRequest(googleReq);
                }, (scope googleRes) {
                    auto userInfo = googleRes.readJson();
                    if ("error" !in userInfo) {
                        User user = {
                            email: userInfo["email"].get!string,
                            name: userInfo["name"].get!string,
                            avatarUrl: userInfo["picture"].get!string,
                            googleId: userInfo["id"].get!string
                        };
                        user = users.loginOrSignup!"googleId"(user);
                        req.session.set("user", user);
                        assert(isLoggedIn(req));
                        return res.redirect(finalRedirectUri);
                    }
                    res.redirect("/api/user/login/error");
                });
            }
        });

        router.get("/api/user/login/github", (req, res) {
            // TODO: necessary?
            if (isLoggedIn(req)) {
                return res.redirect(finalRedirectUri);
            } else if (webapp.login(req, res, githubOAuthSettings, null, githubScopes)) {
                // TODO: oauth.session is fetched from session store (was set in webapp.login)
                auto session = webapp.oauthSession(req);
                requestHTTP("https://api.github.com/user", delegate(scope githubReq) {
                    githubReq.headers["Accept"] = "application/vnd.github.v3+json";
                    session.authorizeRequest(githubReq);
                }, delegate(scope githubRes) {
                    auto userInfo = githubRes.readJson();

                    // TODO: join requests!
                    requestHTTP("https://api.github.com/user/emails", delegate(scope githubReq) {
                        githubReq.headers["Accept"] = "application/vnd.github.v3+json";
                        session.authorizeRequest(githubReq);
                    }, delegate(scope emailRes) {
                        auto userEmail = emailRes.readJson();

                        import vibe.http.common : enforceBadRequest;

                        enforceBadRequest(userEmail.length >= 1, "At least one email expected");

                        User user = {
                            name: userInfo["name"].get!string,
                            email: userEmail[0]["email"].get!string,
                            avatarUrl: userInfo["avatar_url"].get!string,
                            githubId: userInfo["id"].get!long
                        };
                        user = users.loginOrSignup!"githubId"(user);
                        req.session.set("user", user);

                        assert(isLoggedIn(req));
                        res.redirect(finalRedirectUri);
                    });
                });
            }
        });
    }
}
