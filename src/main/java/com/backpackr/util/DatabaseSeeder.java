package com.backpackr.util;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;

public class DatabaseSeeder {

    public static void seedPlacesIfEmpty() {
        String countSql = "SELECT COUNT(*) FROM PLACES";
        try (
            Connection con = DBConnection.getConnection();
            Statement stmt = con.createStatement();
            ResultSet rs = stmt.executeQuery(countSql)
        ) {
            if (rs.next() && rs.getInt(1) > 0) {
                System.out.println("PLACES table is already seeded with " + rs.getInt(1) + " rows.");
                return;
            }

            System.out.println("PLACES table is empty. Starting database seeding...");

            String insertSql = "INSERT INTO PLACES (PLACE_NAME, DISTRICT, STATE, CATEGORY, DESCRIPTION, LATITUDE, LONGITUDE, IMAGE_URL) "
                             + "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

            try (PreparedStatement ps = con.prepareStatement(insertSql)) {
                // --- GOA PLACES ---
                // 1. Dudhsagar Falls (Hidden Gem)
                addPlaceBatch(ps, "Dudhsagar Falls", "Goa", "Goa", "Hidden Gem",
                    "Majestic four-tiered waterfall on the Mandovi River, surrounded by dense deciduous forests with rich biodiversity. A true hidden jungle adventure.",
                    15.3179, 74.3144, "https://images.unsplash.com/photo-1607584102611-6677f5255476?auto=format&fit=crop&w=800&q=80");

                // 2. Palolem Beach (Scenic Spot)
                addPlaceBatch(ps, "Palolem Beach", "Goa", "Goa", "Scenic Spot",
                    "A beautiful crescent-shaped beach lined with coconut palms and colourful shacks, famous for its calm waters and silent noise disco nights.",
                    15.0100, 74.0200, "https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=800&q=80");

                // 3. St. Anthony's Shack (Budget Food)
                addPlaceBatch(ps, "St. Anthony's Shack", "Goa", "Goa", "Budget Food",
                    "A lively, affordable beachside dining spot in Baga known for mouth-watering butter garlic prawns, traditional fish curry, and karaoke nights.",
                    15.2289, 73.9790, "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80");

                // 4. Fort Aguada (Local Attraction)
                addPlaceBatch(ps, "Fort Aguada", "Goa", "Goa", "Local Attraction",
                    "A well-preserved 17th-century Portuguese fort and lighthouse standing on Sinquerim Beach, offering scenic views of the Arabian Sea.",
                    15.4926, 73.7738, "https://images.unsplash.com/photo-1582236968750-f33190be9057?auto=format&fit=crop&w=800&q=80");

                // --- MUMBAI PLACES ---
                // 5. Kanheri Caves (Hidden Gem)
                addPlaceBatch(ps, "Kanheri Caves", "Mumbai", "Maharashtra", "Hidden Gem",
                    "A group of ancient rock-cut caves and monuments nestled in the forests of Sanjay Gandhi National Park, showcasing Buddist carvings and water systems.",
                    19.2061, 72.9069, "https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=800&q=80");

                // 6. Marine Drive (Scenic Spot)
                addPlaceBatch(ps, "Marine Drive", "Mumbai", "Maharashtra", "Scenic Spot",
                    "A 3-kilometer-long promenade bordering the Arabian Sea. It is also known as the Queen's Necklace because of the street lights glowing like pearls at night.",
                    18.9430, 72.8230, "https://images.unsplash.com/photo-1496372412473-e8548ffd82bc?auto=format&fit=crop&w=800&q=80");

                // 7. Sardar Refreshments (Budget Food)
                addPlaceBatch(ps, "Sardar Refreshments", "Mumbai", "Maharashtra", "Budget Food",
                    "An iconic, budget-friendly eatery near Tardeo famous for its unbelievably buttery Pav Bhaji, serving tourists and locals alike for decades.",
                    18.9686, 72.8188, "https://images.unsplash.com/photo-1606491956689-2ea866880c84?auto=format&fit=crop&w=800&q=80");

                // 8. Gateway of India (Local Attraction)
                addPlaceBatch(ps, "Gateway of India", "Mumbai", "Maharashtra", "Local Attraction",
                    "An iconic arch monument built during the 20th century to commemorate the landing of King George V. A primary hub for boat rides to Elephanta Caves.",
                    18.9220, 72.8347, "https://images.unsplash.com/photo-1566552881560-0be862a7c445?auto=format&fit=crop&w=800&q=80");

                // --- KERALA PLACES ---
                // 9. Marari Secret Beach (Hidden Gem)
                addPlaceBatch(ps, "Marari Secret Beach", "Alappuzha", "Kerala", "Hidden Gem",
                    "An untouched, quiet white-sand beach near Mararikulam. Ideal for budget travelers seeking peace, stunning sunrises, and fishing village vibes.",
                    9.6015, 76.2974, "https://images.unsplash.com/photo-1540206395-68808572332f?auto=format&fit=crop&w=800&q=80");

                // 10. Athirappilly Waterfalls (Scenic Spot)
                addPlaceBatch(ps, "Athirappilly Waterfalls", "Thrissur", "Kerala", "Scenic Spot",
                    "India's largest waterfall, dropping 80 feet through lush green rain forests. Famously featured in several cinematic blockbusters.",
                    10.2851, 76.5698, "https://images.unsplash.com/photo-1595818985109-df214ab413d0?auto=format&fit=crop&w=800&q=80");

                // 11. Dhe Puttu (Budget Food)
                addPlaceBatch(ps, "Dhe Puttu", "Kochi", "Kerala", "Budget Food",
                    "A very popular yet budget-friendly restaurant in Kochi serving highly creative and delicious variations of Kerala's classic steamed rice cake (Puttu).",
                    9.9961, 76.2995, "https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=800&q=80");

                // 12. Fort Kochi (Local Attraction)
                addPlaceBatch(ps, "Fort Kochi", "Kochi", "Kerala", "Local Attraction",
                    "A historic seaside town famous for its giant Chinese Fishing Nets, colonial Portuguese architecture, murals, and cozy art cafes.",
                    9.9678, 76.2427, "https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=800&q=80");

                ps.executeBatch();
                System.out.println("PLACES table seeded successfully!");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static void addPlaceBatch(PreparedStatement ps, String name, String district, String state, 
                                     String category, String description, double lat, double lon, String imgUrl) throws Exception {
        ps.setString(1, name);
        ps.setString(2, district);
        ps.setString(3, state);
        ps.setString(4, category);
        ps.setString(5, description);
        ps.setDouble(6, lat);
        ps.setDouble(7, lon);
        ps.setString(8, imgUrl);
        ps.addBatch();
    }

    public static void main(String[] args) {
        seedPlacesIfEmpty();
    }
}
