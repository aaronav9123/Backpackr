package com.backpackr.util;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Loads server-side secrets (Gemini API key, etc.) from
 * WEB-INF/config.properties. Never expose these values to the client.
 */
public class Config {

    private static final Properties PROPS = new Properties();
    private static boolean loaded = false;

    private static synchronized void load() {
        if (loaded) return;
        try (InputStream in = Config.class.getClassLoader()
                .getResourceAsStream("config.properties")) {
            if (in != null) {
                PROPS.load(in);
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        loaded = true;
    }

    public static String get(String key, String defaultValue) {
        load();
        String fromFile = PROPS.getProperty(key);
        if (fromFile != null && !fromFile.trim().isEmpty()) {
            return fromFile.trim();
        }
        String fromEnv = System.getenv(key);
        if (fromEnv != null && !fromEnv.trim().isEmpty()) {
            return fromEnv.trim();
        }
        return defaultValue;
    }

    public static String getGeminiApiKey() {
        return get("GEMINI_API_KEY", "");
    }
}
