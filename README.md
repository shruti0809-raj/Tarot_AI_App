AI Tarot App
This is a tarot reading mobile app I built using Flutter and Firebase, along with an AI content pipeline for generating cards, meanings, and visual assets.
I worked on this end to end starting from the idea, user flows, and product structure to development, backend systems, AI content creation, testing, and release on the Play Store.
Play Store link
https://play.google.com/store/apps/details?id=com.taowalker.divineguidance
The focus was to build something that feels intuitive and personal for users but is also structured like a real product with scalability, monetization, and clean architecture in place.
The core experience of the app is based on guided tarot readings. Users can choose from six types of readings including love, career, horoscope, daily sunshine, personal question, and angel guidance. Each reading presents a specific spread where users are asked to select a certain number of cards from a shuffled deck. Once all selections are made, the app shows a summary of the chosen cards, and then generates a final reading.
The reading itself is created through an AI pipeline where each card is indexed and tracked even after shuffling. The selected card indices are passed into ChatGPT, which then generates a structured and holistic interpretation based on the reading type and the combination of cards. This allows each session to feel dynamic and personalized rather than static.
The app also allows users to switch between different decks, save their readings, share them on WhatsApp or other apps, and download them locally on the device. There is also a daily three card feature designed to create a habit loop and bring users back regularly.
I built a full AI pipeline where all cards, meanings, and even design directions were generated and refined.
Some key parts of what I built
• Frontend built in Flutter with BLoC based architecture and custom animations like parallax and subtle motion effects
• Backend using Firebase including authentication, Firestore database, storage, analytics, and crash tracking, along with some structured logic using Spring Boot
• Phone number login with OTP across regions, onboarding flow, free credit system, and a wallet with balance ledger
• Logic to prevent misuse of free credits even if a user deletes and recreates an account using the same number
• Five AI generated decks including Tarot with 72 cards, Oracle with 52 cards, Messages with 104 cards, Charms with 20 cards, and Affirmations with 40 cards
• Six structured reading flows where users select cards and receive an AI generated interpretation based on indexed selections
• Daily three card feature to create repeat engagement
• Save readings with history tracking, share to WhatsApp and other platforms, and download on device
• Monetization through in app purchases using Google Play Billing with different usage flows
• Firestore based structured data model for users and transaction ledgers with controlled access and security rules
• Privacy policy, terms and conditions, billing information, and user controls like profile, account deactivation, and deletion
• Performance optimizations like lazy loading, caching, asset compression, and efficient database reads and writes
• Testing across unit, widget, and integration levels along with Firebase emulators
• Release through Google Play Console with pre launch testing and vitals monitoring
This project was built as a complete working product and not just a prototype. It went from idea to a live app with real users, payments, and analytics, and also gave me a reusable AI system for building similar applications in the future.
