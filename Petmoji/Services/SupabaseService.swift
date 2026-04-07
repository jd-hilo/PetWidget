import Foundation
import Supabase

// MARK: - Supabase Service

final class SupabaseService: @unchecked Sendable {
    static let shared = SupabaseService()

    // Replace with your actual Supabase project values
    private let supabaseURL = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://myzcaywwxmjzrsjpcjhh.supabase.co")!
    private let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15emNheXd3eG1qenJzanBjamhoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5ODY5MTcsImV4cCI6MjA4NzU2MjkxN30.JC275740QikWldaTrMArjpBjdmhdCvXg3cgTGjMakHY"

    lazy var client: SupabaseClient = {
        SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }()

    private init() {}

    // MARK: - Auth

    func signInAnonymously() async throws -> UUID {
        let session = try await client.auth.signInAnonymously()
        return session.user.id
    }

    func currentUserId() async throws -> UUID {
        let session = try await client.auth.session
        return session.user.id
    }

    // MARK: - Pet CRUD

    func fetchCurrentPet() async throws -> Pet? {
        let userId = try await currentUserId()
        let pets: [Pet] = try await client
            .from("pets")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return pets.first
    }

    func savePet(_ pet: Pet) async throws -> Pet {
        let saved: Pet = try await client
            .from("pets")
            .upsert(pet)
            .select()
            .single()
            .execute()
            .value
        return saved
    }

    func updatePetExpressions(petId: UUID, expressions: ExpressionMap) async throws {
        try await client
            .from("pets")
            .update(["expressions": expressions])
            .eq("id", value: petId.uuidString)
            .execute()
    }

    func updatePetName(petId: UUID, name: String) async throws {
        try await client
            .from("pets")
            .update(["name": name])
            .eq("id", value: petId.uuidString)
            .execute()
    }

    func updatePetHomeLocation(petId: UUID, lat: Double, lng: Double) async throws {
        try await client
            .from("pets")
            .update(["home_lat": lat, "home_lng": lng])
            .eq("id", value: petId.uuidString)
            .execute()
    }

    func getStoredPhotoURLs(petId: UUID) async throws -> [String] {
        var urls: [String] = []
        for i in 0..<5 {
            let path = "\(petId.uuidString)/photo_\(i).jpg"
            if let url = try? await client.storage
                .from("pet-photos")
                .createSignedURL(path: path, expiresIn: 3600) {
                urls.append(url.absoluteString)
            }
        }
        return urls
    }

    // MARK: - Messages

    func fetchLatestMessage(for petId: UUID) async throws -> PetMessage? {
        let messages: [PetMessage] = try await client
            .from("messages")
            .select()
            .eq("pet_id", value: petId.uuidString)
            .not("sent_at", operator: .is, value: "null")
            .order("sent_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return messages.first
    }

    func fetchRecentMessages(for petId: UUID, limit: Int = 20) async throws -> [PetMessage] {
        let messages: [PetMessage] = try await client
            .from("messages")
            .select()
            .eq("pet_id", value: petId.uuidString)
            .not("sent_at", operator: .is, value: "null")
            .order("sent_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return messages
    }

    func saveMessage(_ message: PetMessage) async throws {
        try await client
            .from("messages")
            .insert(message)
            .execute()
    }

    // MARK: - Storage

    func uploadPetPhoto(petId: UUID, imageData: Data, index: Int) async throws -> String {
        let path = "\(petId.uuidString)/photo_\(index).jpg"
        try await client.storage
            .from("pet-photos")
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        let publicURL = try client.storage
            .from("pet-photos")
            .getPublicURL(path: path)
        return publicURL.absoluteString
    }

    func downloadSprite(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    // MARK: - Sprite Generation (calls edge function)

    func generateSprites(petId: UUID, photoURLs: [String], species: Species, gender: PetGender) async throws -> ExpressionMap {
        struct GenerateRequest: Encodable {
            let petId: String
            let photoURLs: [String]
            let species: String
            let gender: String
            enum CodingKeys: String, CodingKey {
                case petId = "pet_id"
                case photoURLs = "photo_urls"
                case species
                case gender
            }
        }
        let response: ExpressionMap = try await client.functions
            .invoke(
                "generate-sprites",
                options: FunctionInvokeOptions(
                    body: GenerateRequest(
                        petId: petId.uuidString,
                        photoURLs: photoURLs,
                        species: species.rawValue,
                        gender: gender.rawValue
                    )
                )
            )
        return response
    }

    // MARK: - Device token registration (APNs)

    func registerDeviceToken(_ token: String) async throws {
        let userId = try await currentUserId()
        let environment = Bundle.main.object(forInfoDictionaryKey: "APS_ENVIRONMENT") as? String ?? "development"
        try await client
            .from("device_tokens")
            .upsert([
                "user_id": userId.uuidString,
                "token": token,
                "platform": "ios",
                "environment": environment,
            ], onConflict: "user_id, token")
            .execute()
    }

    // MARK: - Location event (calls edge function)

    func reportLocationEvent(petId: UUID, event: String) async throws -> PetMessage {
        struct LocationRequest: Encodable {
            let petId: String
            let event: String
            enum CodingKeys: String, CodingKey {
                case petId = "pet_id"
                case event
            }
        }
        let response: PetMessage = try await client.functions
            .invoke(
                "location-event",
                options: FunctionInvokeOptions(
                    body: LocationRequest(petId: petId.uuidString, event: event)
                )
            )
        return response
    }
}
