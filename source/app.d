import std.stdio;
import std.file;
import dlogg.log;
import dlogg.strict;
import argon;
import config;
import router;

public class MainHandler {
    private shared StrictLogger logger;

    this() {
        logger = new shared StrictLogger("server.log");
        logger.minOutputLevel = LoggingLevel.Notice;
    }

    private class Args : argon.Handler {
        string configFilePath;

        this() {
            Named("config", configFilePath)('c')("Config file path");
        }
    }

    auto run(string[] args) {
        auto argsParser = new Args();

        try {
            argsParser.Parse(args);
        } catch (argon.ParseException e) {
            logger.logError(e.msg);
            logger.logError(argsParser.BuildSyntaxSummary);
            return 1;
        }

        Config config;
        try {
            import json = vibe.data.json;

            auto jsonText = readText(argsParser.configFilePath);
            config = json.deserializeJson!Config(jsonText);
        } catch (Exception e) {
            logger.logError("An error occurred while loading the configuration file");
            return 1;
        }

        auto router = new Router(logger, config);
        router.run();

        return 0;
    }
}

int main(string[] args) {
    auto mainHandler = new MainHandler();
    return mainHandler.run(args);
}
