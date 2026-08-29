package com.backpackr.util;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.backpackr.model.Place;

/**
 * Wraps the Google Gemini generateContent API. The model is given the
 * community-contributed places already in Backpackr's own database and is
 * instructed to build the itinerary ONLY from that list (by PLACE_ID) rather
 * than inventing new destinations.
 */
public class GeminiService {

    private static final String MODEL = "gemini-2.5-flash";
    private static final String ENDPOINT =
        "https://generativelanguage.googleapis.com/v1beta/models/" + MODEL + ":generateContent";

    public static class ItineraryStop {
        public int placeId;
        public String note;
    }

    public static class ItineraryDay {
        public int dayNumber;
        public String summary;
        public List<ItineraryStop> stops = new ArrayList<>();
    }

    public static class ItineraryResult {
        public boolean success;
        public String errorMessage;
        public String overallSummary;
        public List<ItineraryDay> days = new ArrayList<>();
    }

    /**
     * @param selectedPlaces places the user has already added ("+") to the active trip
     * @param candidatePool  broader pool of DB places near the destination the AI may also draw from
     * @param days           number of days for the trip
     * @param budget         total budget in Rs
     * @param travelMode     e.g. "Car", "Bike", "Public Transport", "Walking"
     * @param groupType      e.g. "Solo", "Couple", "Family", "Friends"
     * @param interests      e.g. "Nature, Food, Adventure"
     * @param adventureLevel e.g. "Relaxed", "Moderate", "High"
     */
    public ItineraryResult generateItinerary(
            List<Place> selectedPlaces, List<Place> candidatePool,
            int days, double budget, String travelMode, String groupType,
            String interests, String adventureLevel) {

        ItineraryResult result = new ItineraryResult();
        String apiKey = Config.getGeminiApiKey();

        if (apiKey == null || apiKey.isEmpty()) {
            result.success = false;
            result.errorMessage = "Gemini API key is not configured on the server.";
            return result;
        }

        try {
            String prompt = buildPrompt(selectedPlaces, candidatePool, days, budget,
                    travelMode, groupType, interests, adventureLevel);

            String requestBody = buildRequestBody(prompt);

            HttpClient client = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(20))
                    .build();

            HttpRequest httpRequest = HttpRequest.newBuilder()
                    .uri(URI.create(ENDPOINT + "?key=" + apiKey))
                    .timeout(Duration.ofSeconds(45))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();

            HttpResponse<String> response = client.send(httpRequest, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                result.success = false;
                result.errorMessage = "Gemini API returned status " + response.statusCode()
                        + ": " + truncate(response.body(), 300);
                return result;
            }

            String modelText = extractModelText(response.body());
            if (modelText == null) {
                result.success = false;
                result.errorMessage = "Gemini returned an unexpected response shape.";
                return result;
            }

            parseItineraryJson(modelText, result);
            result.success = true;
            return result;

        } catch (Exception e) {
            e.printStackTrace();
            result.success = false;
            result.errorMessage = "Could not reach the AI planner: " + e.getMessage();
            return result;
        }
    }

    // ==========================================================
    // Prompt construction
    // ==========================================================
    private String buildPrompt(List<Place> selectedPlaces, List<Place> candidatePool,
            int days, double budget, String travelMode, String groupType,
            String interests, String adventureLevel) {

        StringBuilder sb = new StringBuilder();
        sb.append("You are Backpackr's trip planning assistant. Build a day-wise travel ")
          .append("itinerary using ONLY the places listed below (they come from Backpackr's ")
          .append("own community-contributed database). Never invent a place that is not in ")
          .append("this list. Refer to each chosen place strictly by its PLACE_ID.\n\n");

        sb.append("Trip preferences:\n")
          .append("- Number of days: ").append(days).append("\n")
          .append("- Total budget (INR): ").append(budget).append("\n")
          .append("- Travel mode: ").append(travelMode).append("\n")
          .append("- Group type: ").append(groupType).append("\n")
          .append("- Interests: ").append(interests).append("\n")
          .append("- Adventure level: ").append(adventureLevel).append("\n\n");

        if (!selectedPlaces.isEmpty()) {
            sb.append("Places the user has already hand-picked and definitely wants included:\n");
            appendPlaceList(sb, selectedPlaces);
            sb.append("\n");
        }

        sb.append("Additional candidate places you may use to fill out the itinerary:\n");
        appendPlaceList(sb, candidatePool);

        sb.append("\nRespond with ONLY valid JSON (no markdown fences, no commentary) in exactly ")
          .append("this shape:\n")
          .append("{\n")
          .append("  \"overallSummary\": \"1-2 sentence overview of the plan and how it fits the budget\",\n")
          .append("  \"days\": [\n")
          .append("    {\n")
          .append("      \"dayNumber\": 1,\n")
          .append("      \"summary\": \"short description of the day's theme\",\n")
          .append("      \"stops\": [ { \"placeId\": 12, \"note\": \"why/when to visit, 1 sentence\" } ]\n")
          .append("    }\n")
          .append("  ]\n")
          .append("}\n")
          .append("Distribute stops sensibly across the requested number of days, respect the ")
          .append("budget where possible, and prefer geographically close places on the same day.");

        return sb.toString();
    }

    private void appendPlaceList(StringBuilder sb, List<Place> places) {
        for (Place p : places) {
            sb.append("- PLACE_ID ").append(p.getPlaceId())
              .append(" | ").append(p.getPlaceName())
              .append(" | category: ").append(p.getCategory())
              .append(" | ").append(p.getDistrict()).append(", ").append(p.getState())
              .append(" | approx cost: Rs.").append((int) p.getAvgCost())
              .append(" | lat/lng: ").append(p.getLatitude()).append(",").append(p.getLongitude())
              .append("\n");
        }
    }

    // ==========================================================
    // Gemini request/response plumbing
    // ==========================================================
    private String buildRequestBody(String prompt) {
        StringBuilder json = new StringBuilder();
        json.append("{")
            .append("\"contents\":[{\"parts\":[{\"text\":\"").append(SimpleJson.escape(prompt)).append("\"}]}],")
            .append("\"generationConfig\":{\"responseMimeType\":\"application/json\",\"temperature\":0.4}")
            .append("}");
        return json.toString();
    }

    @SuppressWarnings("unchecked")
    private String extractModelText(String responseBody) {
        Object parsed = SimpleJson.parse(responseBody);
        if (!(parsed instanceof Map)) return null;
        Map<String, Object> root = (Map<String, Object>) parsed;
        Object candidatesObj = root.get("candidates");
        if (!(candidatesObj instanceof List) || ((List<?>) candidatesObj).isEmpty()) return null;

        Map<String, Object> firstCandidate = (Map<String, Object>) ((List<?>) candidatesObj).get(0);
        Object contentObj = firstCandidate.get("content");
        if (!(contentObj instanceof Map)) return null;

        Object partsObj = ((Map<String, Object>) contentObj).get("parts");
        if (!(partsObj instanceof List) || ((List<?>) partsObj).isEmpty()) return null;

        Map<String, Object> firstPart = (Map<String, Object>) ((List<?>) partsObj).get(0);
        Object text = firstPart.get("text");
        return text != null ? text.toString() : null;
    }

    @SuppressWarnings("unchecked")
    private void parseItineraryJson(String modelText, ItineraryResult result) {
        Object parsed = SimpleJson.parse(modelText.trim());
        if (!(parsed instanceof Map)) {
            result.overallSummary = "AI planner returned an unexpected format.";
            return;
        }
        Map<String, Object> root = (Map<String, Object>) parsed;
        result.overallSummary = String.valueOf(root.getOrDefault("overallSummary", ""));

        Object daysObj = root.get("days");
        if (daysObj instanceof List) {
            for (Object dayObj : (List<Object>) daysObj) {
                if (!(dayObj instanceof Map)) continue;
                Map<String, Object> dayMap = (Map<String, Object>) dayObj;

                ItineraryDay day = new ItineraryDay();
                day.dayNumber = toInt(dayMap.get("dayNumber"), result.days.size() + 1);
                day.summary = String.valueOf(dayMap.getOrDefault("summary", ""));

                Object stopsObj = dayMap.get("stops");
                if (stopsObj instanceof List) {
                    for (Object stopObj : (List<Object>) stopsObj) {
                        if (!(stopObj instanceof Map)) continue;
                        Map<String, Object> stopMap = (Map<String, Object>) stopObj;
                        ItineraryStop stop = new ItineraryStop();
                        stop.placeId = toInt(stopMap.get("placeId"), -1);
                        stop.note = String.valueOf(stopMap.getOrDefault("note", ""));
                        if (stop.placeId > 0) {
                            day.stops.add(stop);
                        }
                    }
                }
                result.days.add(day);
            }
        }
    }

    private int toInt(Object value, int fallback) {
        if (value instanceof Number) return ((Number) value).intValue();
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (Exception e) {
            return fallback;
        }
    }

    private String truncate(String s, int maxLen) {
        if (s == null) return "";
        return s.length() <= maxLen ? s : s.substring(0, maxLen) + "...";
    }
}
