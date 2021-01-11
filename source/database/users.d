module database.users;

import vibe.data.bson : BsonObjectID;
import vibe.db.mongo.mongo;
import std.typecons : tuple;

import database.journal;

struct User {
    import vibe.data.serialization : dbName = name;

    @dbName("_id")
    BsonObjectID id;

    string email;
    string name;
    long githubId;
    string googleId;
    string avatarUrl;

    immutable(Journal)[] journals;
}

// TLS instance
UserController users;

class UserController {
    private MongoCollection users;

    this(MongoDatabase db) {
        users = db["users"];

        IndexOptions options;
        options.unique = true;
        options.sparse = true;

        {
            IndexModel[1] models;
            models[0].options = options;
            models[0].add("googleId", 1);
            users.createIndex(models);
        }

        {
            IndexModel[1] models;
            models[0].options = options;
            models[0].add("githubId", 1);
            users.createIndex(models);
        }
    }

    User loginOrSignup(string providerId)(User user) {
        auto u = users.findOne!User([providerId: mixin("user." ~ providerId)]);
        if (!u.isNull) {
            // TODO: should we update attributes?
            return u.get;
        } else {
            return addUser(user);
        }
    }

    bool quit(string providerId)(User user) {
        immutable auto u = users.findOne!User([providerId: mixin("user." ~ providerId)]);
        if (!u.isNull) {
            deleteUser(user);
            return true;
        } else {
            return false;
        }
    }

    User addUser(User user) {
        user.id = BsonObjectID.generate();
        users.insert(user);
        return user;
    }

    void deleteUser(User user) {
        users.remove(user);
    }

    void updateToken(string id, string token) {
        users.update(["id": id], ["$set": token]);
    }
}
