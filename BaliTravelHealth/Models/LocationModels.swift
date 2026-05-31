import Foundation

struct LocationClassification: Decodable, Sendable {
    let inBali: Bool?
    let region: String?
    let latitude: Double?
    let longitude: Double?
    let zone: String
    let label: String
    let nearestFacilityKm: Double?

    private enum CodingKeys: String, CodingKey {
        case inBali
        case region
        case latitude
        case longitude
        case zone
        case label
        case nearestFacilityKm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inBali = try container.decodeIfPresent(Bool.self, forKey: .inBali)
        region = try container.decodeIfPresent(String.self, forKey: .region)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        zone = try container.decodeIfPresent(String.self, forKey: .zone) ?? (inBali == true ? "bali" : "outside_bali")
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? region ?? zone
        nearestFacilityKm = try container.decodeIfPresent(Double.self, forKey: .nearestFacilityKm)
    }
}

struct NearbyHealthFacility: Codable, Identifiable, Sendable {
    let id: Int
    let nama: String
    let jenis: String
    let lat: Double
    let lng: Double
    let jarakKm: Double?
    let telepon: String?

    let alamat: String?
    let jamOperasional: String?

    private enum CodingKeys: String, CodingKey {
        case id, nama, jenis, kategori
        case lat, latitude, lng, longitude
        case jarakKm, distanceKm
        case telepon, kontak
        case alamat
        case jamOperasional
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        nama = try container.decode(String.self, forKey: .nama)
        jenis = try container.decodeIfPresent(String.self, forKey: .jenis)
            ?? container.decodeIfPresent(String.self, forKey: .kategori)
            ?? "Fasilitas Kesehatan"
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
            ?? container.decode(Double.self, forKey: .latitude)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
            ?? container.decode(Double.self, forKey: .longitude)
        jarakKm = try container.decodeIfPresent(Double.self, forKey: .jarakKm)
            ?? container.decodeIfPresent(Double.self, forKey: .distanceKm)
        telepon = try container.decodeIfPresent(String.self, forKey: .telepon)
            ?? container.decodeIfPresent(String.self, forKey: .kontak)
        alamat = try container.decodeIfPresent(String.self, forKey: .alamat)
        jamOperasional = try container.decodeIfPresent(String.self, forKey: .jamOperasional)
    }

    init(
        id: Int,
        nama: String,
        jenis: String,
        lat: Double,
        lng: Double,
        jarakKm: Double? = nil,
        telepon: String? = nil,
        alamat: String? = nil,
        jamOperasional: String? = nil
    ) {
        self.id = id
        self.nama = nama
        self.jenis = jenis
        self.lat = lat
        self.lng = lng
        self.jarakKm = jarakKm
        self.telepon = telepon
        self.alamat = alamat
        self.jamOperasional = jamOperasional
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(nama, forKey: .nama)
        try container.encode(jenis, forKey: .jenis)
        try container.encode(lat, forKey: .lat)
        try container.encode(lng, forKey: .lng)
        try container.encodeIfPresent(jarakKm, forKey: .jarakKm)
        try container.encodeIfPresent(telepon, forKey: .telepon)
        try container.encodeIfPresent(alamat, forKey: .alamat)
        try container.encodeIfPresent(jamOperasional, forKey: .jamOperasional)
    }
}
