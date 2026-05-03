import Foundation
import SwiftData

/// Seed data — 17 BMTA-listed healthcare facilities in Bali.
///
/// ── Sumber Verifikasi ──────────────────────────────────────────────────────
/// Alamat / Telp:
///   • Website resmi masing-masing RS
///   • Australian Embassy Bali Medical List
///   • US Embassy Medical Assistance Indonesia
///   • SIRS Kemkes
///
/// Jam Operasional:
///   • profngoerahhospitalbali.com → Poli: Sen–Jum 07.30–16.00
///   • sipp.menpan.go.id + rsmatabalimandara.baliprov.go.id → Loket 07.30–11.30
///   • rsbm.baliprov.go.id/fqa → Poli detail verified
///   • rstrijata.com → IGD 24 jam confirmed
///   • rs.unud.ac.id/pelayanan-rawat-jalan → Poli: Sen–Sab
///   • bimcbali.com (Kuta & Nusa Dua) → 24 jam confirmed
///   • bali911dentalclinic.com → Sen–Sab hours confirmed
///   • 221assist.com → 24/7 confirmed
///
/// ── Catatan ────────────────────────────────────────────────────────────────
///   ⚠️ = jam diestimasi / tidak dikonfirmasi secara eksplisit
///   Koordinat approksimasi ±100–200 m — validasi dengan MapKit/Google Maps
///
/// Last verified: Mei 2026
enum DatabaseSeeder {

    /// Pre-populate SwiftData ModelContext with all 17 BMTA facilities.
    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) {
        // Check if already seeded
        let descriptor = FetchDescriptor<HealthcareFacility>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0

        guard count == 0 else { return }

        for facility in allFacilities {
            modelContext.insert(facility)
        }

        try? modelContext.save()
    }

    /// All 17 facilities as an array.
    static var allFacilities: [HealthcareFacility] {
        governmentHospitals + privateHospitals + clinics
    }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: - RS PEMERINTAH (6)
    // ════════════════════════════════════════════════════════════════════════

    static var governmentHospitals: [HealthcareFacility] { [

        HealthcareFacility(
            name: "Prof. Ngoerah Hospital",
            officialName: "RSUP Prof. Dr. I.G.N.G. Ngoerah",
            specialty: "Heart Care / Kardiologi",
            type: .government,
            address: "Jl. Diponegoro No. 45, Dauh Puri Klod, Denpasar, Bali 80113",
            phone: "+62 361 227911",
            phoneAlt: "+62 361 227915",
            website: "https://profngoerahhospitalbali.com",
            email: "info@profngoerahhospitalbali.com",
            latitude: -8.6684,
            longitude: 115.2190,
            // Sumber: profngoerahhospitalbali.com/home/pelayanan-rawat-jalan-umum/
            isOpen24Hours: true,
            outpatientHours: """
                Senin – Jumat: 07.30 – 16.00 WITA
                Sabtu & Libur Nasional: Tutup (Poli Umum)
                Wing Amerta (Eksekutif): Senin – Jumat sesi pagi & sore
                Loket pendaftaran: Senin–Kamis 07.00–13.30, Jumat 07.00–13.00
                """,
            emergencyHours: "IGD: 24 jam / 7 hari",
            hoursSummary: "IGD 24 jam  |  Poli: Sen–Jum 07.30–16.00",
            notes: "Rujukan utama Bali. Dulu RS Sanglah. International Wing, 738 TT, 500+ dokter. Lab & Radiologi 24 jam. Hiperbarik, onkologi, transplantasi ginjal."
        ),

        HealthcareFacility(
            name: "RS Mata Bali Mandara",
            officialName: "Rumah Sakit Mata Bali Mandara",
            specialty: "Eye Care / Mata",
            type: .government,
            address: "Jl. Angsoka No. 8, Dangin Puri Kangin, Denpasar Utara, Bali 80236",
            phone: "+62 361 243350",
            website: "https://rsmatabalimandara.baliprov.go.id",
            latitude: -8.6389,
            longitude: 115.2228,
            // Sumber: sipp.menpan.go.id & rsmatabalimandara.baliprov.go.id
            isOpen24Hours: true,
            outpatientHours: """
                Loket Poliklinik: 07.30 – 11.30 WITA (Senin – Jumat)
                Poli VIP: Sesi pagi & sore (dengan perjanjian)
                Sabtu: ⚠️ Terbatas / dengan perjanjian
                """,
            emergencyHours: "IGD Mata: 24 jam / 7 hari",
            hoursSummary: "IGD 24 jam  |  Loket Poli: 07.30–11.30 WITA",
            notes: "RS khusus mata Pemprov Bali Tipe A. Katarak, retina, glaukoma, strabismus, LASIK."
        ),

        HealthcareFacility(
            name: "RSUD Bali Mandara",
            officialName: "Rumah Sakit Umum Daerah Bali Mandara Provinsi Bali",
            specialty: "Cancer / Onkologi Terpadu",
            type: .government,
            address: "Jl. Bypass Ngurah Rai No. 548, Sanur Kauh, Denpasar Selatan, Bali 80234",
            phone: "+62 361 4490566",
            phoneAlt: "+62 812 3712 0596",
            website: "https://rsbm.baliprov.go.id",
            email: "marketingbalimandarahospital@gmail.com",
            latitude: -8.7228,
            longitude: 115.2410,
            // Sumber: rsbm.baliprov.go.id/fqa (resmi, detail)
            isOpen24Hours: true,
            outpatientHours: """
                Poli Pagi:
                  Senin – Kamis: 08.00 – 15.30 WITA
                  Jumat & Sabtu: 08.00 – 13.00 WITA
                Poli Sore:
                  Senin – Jumat: 15.30 – 20.00 WITA
                Pendaftaran online: rsbm.baliprov.go.id | WA: 0812-3712-0596
                """,
            emergencyHours: "IGD: 24 jam / 7 hari",
            hoursSummary: "IGD 24 jam  |  Poli Pagi: Sen–Sab  |  Poli Sore: Sen–Jum",
            notes: "RS daerah Bali kelas B. Layanan kanker terpadu. IGD 24 jam, radiologi, rehabilitasi. BPJS & asuransi."
        ),

        HealthcareFacility(
            name: "RS Bhayangkara Denpasar",
            officialName: "Rumah Sakit Bhayangkara Denpasar (RS Trijata)",
            specialty: "Hyperbaric Medicine / Oksigen Hiperbarik",
            type: .government,
            address: "Jl. Trijata No. 32, Sumerta Kelod, Denpasar Utara, Bali",
            phone: "+62 361 4723350",
            website: "https://rstrijata.com",
            latitude: -8.6473,
            longitude: 115.2299,
            // Sumber: rstrijata.com — IGD 24 jam confirmed
            isOpen24Hours: true,
            outpatientHours: """
                Poliklinik Spesialis:
                  ⚠️ Senin – Jumat: 08.00 – 14.00 WITA (estimasi jam kerja)
                  Sabtu: ⚠️ Terbatas (cek langsung ke RS)
                Poli Hiperbarik: Sesuai jadwal dokter (konfirmasi via telp)
                Home Care: Tersedia
                """,
            emergencyHours: "IGD: 24 jam / 7 hari",
            hoursSummary: "IGD 24 jam  |  Poli: ⚠️ Sen–Jum 08.00–14.00 (estimasi)",
            notes: "RS Polri kelas C. Hiperbarik tersertifikasi DAN. Luka diabetes, dekompresi selam, luka bakar. 109 TT."
        ),

        HealthcareFacility(
            name: "RS Universitas Udayana",
            officialName: "Rumah Sakit Universitas Udayana",
            specialty: "Infectious Diseases / Penyakit Infeksi & Tropis",
            type: .government,
            address: "Jl. Rumah Sakit Universitas Udayana No. 1, Jimbaran, Kuta Selatan, Badung, Bali 80361",
            phone: "+62 361 8953670",
            phoneAlt: "+62 896 0490 0890",
            website: "https://rs.unud.ac.id",
            email: "info@rs.unud.ac.id",
            latitude: -8.7897,
            longitude: 115.1688,
            // Sumber: rs.unud.ac.id/pelayanan-rawat-jalan
            isOpen24Hours: true,
            outpatientHours: """
                Poliklinik Spesialis:
                  ⚠️ Senin – Sabtu: 08.00 – 15.00 WITA (konfirmasi via rs.unud.ac.id)
                Reservasi Poli: +62 831 5958 2772
                Informasi: +62 896 0490 0890
                """,
            emergencyHours: "IGD: 24 jam / 7 hari",
            hoursSummary: "IGD 24 jam  |  Poli: ⚠️ Sen–Sab (konfirmasi via website)",
            notes: "RS perguruan tinggi. Penyakit infeksi & tropis, imunologi, operasi telerobotik. Dekat kampus UNUD Jimbaran."
        ),

        HealthcareFacility(
            name: "RSUD Mangusada Badung",
            officialName: "Rumah Sakit Daerah Mangusada Kabupaten Badung",
            specialty: "Heart & Cancer / Jantung & Onkologi",
            type: .government,
            address: "Jl. Raya Kapal, Mangupura, Mengwi, Badung, Bali 80351",
            phone: "+62 361 9006812",
            phoneAlt: "+62 361 9006813",
            website: "https://rsudmangusada.badungkab.go.id",
            email: "rsdm@rsdmangusada.com",
            latitude: -8.5867,
            longitude: 115.1811,
            // Sumber: Instagram @rsdmangusada
            isOpen24Hours: true,
            outpatientHours: """
                Poliklinik:
                  ⚠️ Senin – Kamis: 08.00 – 14.00 WITA
                  Jumat: 08.00 – 11.00 WITA
                  Sabtu: ⚠️ Terbatas / sebagian poli saja
                WhatsApp (jam kerja): 087850127333
                IGD: +62 361 9006811
                """,
            emergencyHours: "IGD: 24 jam / 7 hari  |  Tel IGD: (0361) 9006811",
            hoursSummary: "IGD 24 jam  |  Poli: ⚠️ Sen–Jum (jam kerja)",
            notes: "RS Kabupaten Badung kelas B. IGD 24 jam, ICU, bedah jantung, kemoterapi, hemodialisis. BPJS & asuransi."
        )
    ] }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: - RS SWASTA (8)
    // ════════════════════════════════════════════════════════════════════════

    static var privateHospitals: [HealthcareFacility] { [

        HealthcareFacility(
            name: "Siloam Hospital Bali",
            officialName: "Siloam Hospitals Bali (Denpasar)",
            specialty: "Orthopedics / Ortopedi",
            type: .privateHospital,
            address: "Jl. Sunset Road No. 818, Kuta, Badung, Bali 80361",
            phone: "+62 361 779900",
            phoneAlt: "1-500-911",
            website: "https://www.siloamhospitals.com/en/rumah-sakit/siloam-hospitals-denpasar",
            email: "info.bali@siloamhospitals.com",
            latitude: -8.7109,
            longitude: 115.1705,
            isOpen24Hours: true,
            outpatientHours: """
                Rawat Jalan / Poliklinik:
                  ⚠️ Senin – Jumat: 08.00 – 20.00 WITA
                  Sabtu: 08.00 – 17.00 WITA
                  Minggu: Sesuai jadwal dokter
                Contact Center: 1-500-911 (24 jam)
                """,
            emergencyHours: "IGD: 24 jam / 7 hari  |  Emergency: 1-500-911",
            hoursSummary: "IGD 24 jam  |  Poli: ⚠️ Sen–Jum 08.00–20.00",
            notes: "Terakreditasi KARS. 124 TT. Ortopedi, trauma, hemodialisis, kemoterapi, NICU. Staf Inggris. Area Kuta."
        ),

        HealthcareFacility(
            name: "BIMC Hospital Nusa Dua",
            officialName: "BIMC Siloam Hospital Nusa Dua",
            specialty: "Cosmetics / Estetika & Bedah Kosmetik",
            type: .privateHospital,
            address: "Kawasan ITDC Blok D, Jl. Nusa Dua, Benoa, Kuta Selatan, Badung, Bali 80363",
            phone: "+62 361 3000911",
            phoneAlt: "+62 811 3896 113",
            website: "https://bimcbali.com",
            email: "info@bimcbali.com",
            latitude: -8.8009,
            longitude: 115.2285,
            // Sumber: bimcbali.com — 24 jam semua unit confirmed
            isOpen24Hours: true,
            outpatientHours: """
                Accident & Emergency Centre: 24 jam / 7 hari
                Medical Centre (Konsultasi, MCU, Hotel Visit): 24 jam / 7 hari
                CosMedic Centre (Bedah Estetik & Kosmetik):
                  ⚠️ Senin – Jumat: 09.00 – 17.00 WITA
                Dental Centre: ⚠️ Sesuai jadwal dokter
                Dialysis Centre: Sesuai jadwal terapi
                """,
            emergencyHours: "A&E: 24 jam / 7 hari  |  Tel: +62 361 3000911",
            hoursSummary: "24 jam / 7 hari (A&E & Medical Centre)",
            notes: "Akreditasi ACHSI Australia. CosMedic, dental, dialisis, emergency 24 jam. Dalam kompleks ITDC, dekat hotel bintang 5."
        ),

        HealthcareFacility(
            name: "BIMC Hospital Kuta",
            officialName: "BIMC Hospital Kuta",
            specialty: "Emergencies / IGD & Gawat Darurat",
            type: .privateHospital,
            address: "Jl. Bypass Ngurah Rai No. 100X, Kuta, Bali 80361",
            phone: "+62 361 761263",
            phoneAlt: "+62 811 3960 8500",
            website: "https://bimcbali.com",
            email: "info@bimcbali.com",
            latitude: -8.7237,
            longitude: 115.1774,
            // Sumber: bimcbali.com/bimc-hospital-kuta — 24 jam semua confirmed
            isOpen24Hours: true,
            outpatientHours: """
                Accident & Emergency Centre: 24 jam / 7 hari
                Medical Centre (Konsultasi, MCU, on-call hotel): 24 jam / 7 hari
                Laboratorium & Farmasi: 24 jam / 7 hari
                Radiologi: 24 jam / 7 hari
                WA Appointment: +62 811 3960 8500
                """,
            emergencyHours: "A&E: 24 jam / 7 hari  |  Tel: +62 361 761263",
            hoursSummary: "24 jam / 7 hari (semua layanan)",
            notes: "Cabang terbesar BIMC. Emergency & trauma 24 jam, ICU, Lab, Radiologi. Rujukan utama wisatawan Kuta/Seminyak. 90+ mitra asuransi."
        ),

        HealthcareFacility(
            name: "Prima Medika Hospital",
            officialName: "Rumah Sakit Umum Prima Medika",
            specialty: "Cancer / Onkologi",
            type: .privateHospital,
            address: "Jl. Pulau Serangan No. 9X, Denpasar, Bali 80232",
            phone: "+62 361 236225",
            website: "https://www.primamedika.com",
            email: "rspmmail@gmail.com",
            latitude: -8.6896,
            longitude: 115.2140,
            isOpen24Hours: true,
            outpatientHours: """
                Rawat Jalan / Poliklinik Spesialis:
                  ⚠️ Senin – Sabtu: 08.00 – 20.00 WITA
                  Minggu: Sesuai jadwal dokter
                Home Clinic: Tersedia
                Medical Coordination (pasien internasional): Sesuai jam kerja
                """,
            emergencyHours: "IGD: 24 jam / 7 hari",
            hoursSummary: "IGD 24 jam  |  Poli: ⚠️ Sen–Sab 08.00–20.00",
            notes: "100 TT, 30+ spesialisasi. Medical coordination untuk pasien internasional. Staf Inggris. Onkologi, neuro, fisiologi."
        ),

        HealthcareFacility(
            name: "Bali Royal Hospital",
            officialName: "BROS — Bali Royal Hospital",
            specialty: "IVF & Plastic Surgery / Fertilisasi & Bedah Plastik",
            type: .privateHospital,
            address: "Jl. Letda Tantular No. 6, Renon, Denpasar Timur, Kota Denpasar, Bali 80234",
            phone: "+62 361 222588",
            website: "https://balimedicalcare.com",
            latitude: -8.6678,
            longitude: 115.2342,
            isOpen24Hours: true,
            outpatientHours: """
                Rawat Jalan & Spesialis:
                  ⚠️ Senin – Sabtu: 08.00 – 20.00 WITA
                  Minggu: Sesuai jadwal dokter
                MCU (Medical Check Up): Senin – Sabtu
                Unit Bersalin / Maternity: 24 jam
                """,
            emergencyHours: "IGD & Bersalin: 24 jam / 7 hari",
            hoursSummary: "IGD 24 jam  |  Poli: ⚠️ Sen–Sab 08.00–20.00",
            notes: "Beroperasi Juli 2010. IVF, bedah plastik, neurologi, pediatri, kardiologi. Di kawasan civic center Renon."
        ),

        HealthcareFacility(
            name: "Kasih Ibu Hospital Saba",
            officialName: "Rumah Sakit Umum Kasih Ibu Saba",
            specialty: "Hyperbaric Surgery / Hiperbarik & Kedokteran Selam",
            type: .privateHospital,
            address: "Jl. Raya Pantai Saba No. 9, Saba, Blahbatuh, Gianyar, Bali 80581",
            phone: "+62 811 398 3030",
            phoneAlt: "+62 811 380 5356",
            website: "https://kih.co.id/our-hospital/kasih-ibu-hospital-saba/",
            email: "care@kasihibuhospital.com",
            latitude: -8.6051,
            longitude: 115.3135,
            isOpen24Hours: true,
            outpatientHours: """
                Poliklinik & Rawat Jalan:
                  ⚠️ Senin – Sabtu: 08.00 – 20.00 WITA
                  Minggu: Sesuai jadwal dokter
                Hiperbarik (HDMC): Jadwal sesuai indikasi medis (konfirmasi via telp)
                Hemodialisis: Sesuai jadwal sesi
                Booking: WA +62 811 398 3030
                """,
            emergencyHours: "IGD & Ambulans: 24 jam / 7 hari  |  Tel: +62 811 380 5356",
            hoursSummary: "IGD 24 jam  |  Poli: ⚠️ Sen–Sab 08.00–20.00",
            notes: "150 TT. Berdiri 2016. RS terlengkap Bali Timur. Hiperbarik (HDMC), neuro, ortopedi. ~45 mnt Denpasar, ~30 mnt Ubud. Staf Inggris & Jepang."
        ),

        HealthcareFacility(
            name: "Kasih Ibu Hospital Denpasar",
            officialName: "Rumah Sakit Umum Kasih Ibu Denpasar",
            specialty: "Neurosurgery / Bedah Saraf",
            type: .privateHospital,
            address: "Jl. Teuku Umar No. 120, Dauh Puri Klod, Denpasar Barat, Bali 80114",
            phone: "+62 361 3003030",
            phoneAlt: "+62 361 223036",
            website: "https://kih.co.id/our-hospital/kasih-ibu-hospital-denpasar/",
            email: "care@kasihibuhospital.com",
            latitude: -8.6674,
            longitude: 115.2070,
            isOpen24Hours: true,
            outpatientHours: """
                Poliklinik / Rawat Jalan:
                  ⚠️ Senin – Sabtu: 08.00 – 20.00 WITA
                  Minggu: Sesuai jadwal dokter
                Poli Admission: (0361) 3004141
                International Division: Senin – Sabtu (jam kerja)
                Hemodialisis & MCU: Sesuai jadwal
                WA Booking: +62 811 398 3030
                """,
            emergencyHours: "IGD & Ambulans: 24 jam / 7 hari  |  Hotline: (0361) 3003030",
            hoursSummary: "IGD 24 jam  |  Poli: ⚠️ Sen–Sab 08.00–20.00",
            notes: "RS induk KIH. Pertama CT & MRI di Bali. EMRAM Level 6. International division untuk wisatawan. Poli Admission: (0361) 3004141."
        ),

        HealthcareFacility(
            name: "RS Mata Ramata",
            officialName: "Rumah Sakit Khusus Mata Ramata",
            specialty: "Eye Care / Oftalmologi Komprehensif",
            type: .privateHospital,
            address: "Jl. Gatot Subroto Barat No. 429, Padangsambian Kaja, Denpasar Barat, Bali 80117",
            phone: "+62 361 429429",
            website: "https://rsmramata.com",
            latitude: -8.6400,
            longitude: 115.1900,
            isOpen24Hours: true,
            outpatientHours: """
                Poliklinik Mata:
                  ⚠️ Senin – Sabtu: 08.00 – 20.00 WITA
                  Minggu: ⚠️ Sesuai kebutuhan / on-call
                Booking via WhatsApp: Tersedia (bahasa Inggris & Indonesia)
                Bedah Elektif (Katarak, LASIK, dll): Jadwal spesifik sesuai dokter
                """,
            emergencyHours: "IGD Mata: 24 jam / 7 hari (on-call dokter spesialis)",
            hoursSummary: "IGD Mata 24 jam  |  Poli: ⚠️ Sen–Sab 08.00–20.00",
            notes: "RS mata swasta pertama Provinsi Bali. 20+ dokter spesialis mata. Katarak, retina, LASIK, strabismus. Kelas C."
        )
    ] }

    // ════════════════════════════════════════════════════════════════════════
    // MARK: - KLINIK (3)
    // ════════════════════════════════════════════════════════════════════════

    static var clinics: [HealthcareFacility] { [

        HealthcareFacility(
            name: "Bali 911 Dental Clinic",
            officialName: "Bali 911 Dental Clinic — Implant Centre",
            specialty: "Dental Care / Gigi & Mulut",
            type: .clinic,
            address: "Jl. Gatot Subroto Barat No. 367, Pemecutan Kaja, Denpasar Utara, Bali 80116",
            phone: "+62 812 3800 911",
            phoneAlt: "+62 838 9972 6765",
            website: "https://bali911dentalclinic.com",
            latitude: -8.6432,
            longitude: 115.1980,
            // Sumber: bali911dentalclinic.com — jam resmi confirmed
            isOpen24Hours: false,
            outpatientHours: """
                Senin – Jumat: 10.00 – 19.30 WITA
                Sabtu: 10.00 – 18.30 WITA
                Minggu & Hari Libur: Tutup (kecuali emergency)
                WA Konsultasi (Sen–Jum): 10.30 – 20.30 WITA
                WA Konsultasi (Sabtu): 10.30 – 19.00 WITA

                Cabang Kuta (Mall Bali Galeria Lt. 2): Jam menyesuaikan mal
                Cabang Kuta Sunset (Jl. Sunsetroad Indah 1 Kav. 7): Sesuai jadwal
                """,
            emergencyHours: "Emergency Gigi (on-call): 24 jam / 7 hari  |  Tel/WA: +62 812 3800 911",
            hoursSummary: "Emergency 24 jam  |  Klinik: Sen–Jum 10.00–19.30, Sab 10.00–18.30",
            notes: "30+ thn pengalaman. Implan, Invisalign, crown, bridge, veneer. Lab on-site (hasil 2–7 hari). 2 cabang di Kuta."
        ),

        HealthcareFacility(
            name: "Penta Medika Clinic",
            officialName: "Klinik Penta Medika",
            specialty: "Medical Evacuation / Evakuasi Medis",
            type: .clinic,
            address: "Jl. Teuku Umar Barat (Marlboro) No. 88, Denpasar, Bali",
            phone: "+62 361 490709",
            phoneAlt: "+62 361 7446144",
            latitude: -8.6639,
            longitude: 115.1992,
            isOpen24Hours: true,
            outpatientHours: """
                Layanan Klinis & Konsultasi:
                  ⚠️ Senin – Jumat: 08.00 – 17.00 WITA (jam kerja)
                  Sabtu: ⚠️ Terbatas (konfirmasi via telp)
                Evakuasi Medis & Dokter On-call:
                  24 jam / 7 hari (by appointment / emergency)
                Manajemen asuransi internasional: Jam kerja
                """,
            emergencyHours: "Medical Evacuation On-call: 24 jam / 7 hari",
            hoursSummary: "Evakuasi 24 jam  |  Klinik: ⚠️ Sen–Jum 08.00–17.00",
            notes: "Klinik evakuasi medis berlisensi. Evakuasi darat/udara, dokter on-call, manajemen pasien asuransi internasional. Bilingual Inggris/Indonesia."
        ),

        HealthcareFacility(
            name: "221 Assist Clinic",
            officialName: "221 Assist — Medical Assistance & Evacuation",
            specialty: "Medical Evacuation / Evakuasi & Repatriasi",
            type: .clinic,
            address: "Jl. Anyelir No. 8, Denpasar, Bali",
            phone: "+62 815 5822 1221",
            website: "https://www.221assist.com",
            email: "service@221assist.com",
            latitude: -8.6560,
            longitude: 115.2200,
            // Sumber: 221assist.com — 24/7 confirmed
            isOpen24Hours: true,
            outpatientHours: """
                Semua layanan: 24 jam / 7 hari
                  • Medivac darat / udara / laut
                  • Medical & non-medical escort penerbangan
                  • Repatriasi jenazah
                  • Doctor home visit 24 jam
                  • Klinik industri & standby medis event
                Kantor (konsultasi tatap muka): ⚠️ Jam kerja
                """,
            emergencyHours: "On-call 24 jam / 7 hari  |  Tel: +62 815 5822 1221\nEmail: service@221assist.com",
            hoursSummary: "24 jam / 7 hari (semua layanan evakuasi)",
            notes: "Berdiri 2009. Medivac darat/udara/laut, repatriasi jenazah, dokter home visit 24 jam. Beroperasi di seluruh Indonesia. Berbahasa Inggris."
        )
    ] }
}
