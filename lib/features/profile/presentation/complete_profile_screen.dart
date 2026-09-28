import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/profile_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _purokController = TextEditingController();

  // Dropdown Selections
  String _selectedNationality = 'Filipino'; // Default selection
  final String _selectedProvince = 'Sorsogon';
  String? _selectedMunicipality;
  String? _selectedBarangay;

  // List of Nationalities
  final List<String> _nationalityOptions = [
    'Filipino',
    'American',
    'Australian',
    'Canadian',
    'Chinese',
    'British',
    'Japanese',
    'Korean',
    'Other',
  ];

  // Comprehensive mapping of Municipalities and their Barangays
  final Map<String, List<String>> _municipalityBarangays = {
    'Barcelona': [
      "Alegria",
      "Bagacay",
      "Bangate",
      "Bugtong",
      "Cagang",
      "Fabrica",
      "Jibong",
      "Lago",
      "Layog",
      "Luneta",
      "Macabari",
      "Mapapac",
      "Olandia",
      "Paghaluban",
      "Poblacion Central",
      "Poblacion Norte",
      "Poblacion Sur",
      "Putiao",
      "San Antonio",
      "San Isidro",
      "San Ramon",
      "San Vicente",
      "Santa Cruz",
      "Santa Lourdes",
      "Tagdon",
    ],
    'Bulan': [
      "A. Bonifacio",
      "Abad Santos",
      "Aguinaldo",
      "Antipolo",
      "Beguin",
      "Benigno S. Aquino",
      "Bical",
      "Bonga",
      "Butag",
      "Cadandanan",
      "Calomagon",
      "Calpi",
      "Cocok-Cabitan",
      "Daganas",
      "Danao",
      "Dolos",
      "E. Quirino",
      "Fabrica",
      "G. del Pilar",
      "Gate",
      "Inararan",
      "J. Gerona",
      "J. P. Laurel",
      "Jamorawon",
      "Lajong",
      "Libertad",
      "M. Roxas",
      "Magsaysay",
      "Managanaga",
      "Marinab",
      "Montecalvario",
      "N. Roque",
      "Namo",
      "Nasuje",
      "Obrero",
      "Osmeña",
      "Otavi",
      "Padre Diaz",
      "Palale",
      "Quezon",
      "R. Gerona",
      "Recto",
      "Sagrada",
      "San Francisco",
      "San Isidro",
      "San Juan Bag-o",
      "San Juan Daan",
      "San Rafael",
      "San Ramon",
      "San Vicente",
      "Santa Remedios",
      "Santa Teresita",
      "Sigad",
      "Somagongsong",
      "Taromata",
      "Zone I Poblacion",
      "Zone II Poblacion",
      "Zone III Poblacion",
      "Zone IV Poblacion",
      "Zone V Poblacion",
      "Zone VI Poblacion",
      "Zone VII Poblacion",
      "Zone VIII Poblacion",
    ],
    'Bulusan': [
      "Bagacay",
      "Central",
      "Cogon",
      "Dancalan",
      "Dapdap",
      "Lalud",
      "Looban",
      "Mabuhay",
      "Madlawon",
      "Poctol",
      "Porog",
      "Sabang",
      "Salvacion",
      "San Antonio",
      "San Bernardo",
      "San Francisco",
      "San Isidro",
      "San Jose",
      "San Rafael",
      "San Roque",
      "San Vicente",
      "Santa Barbara",
      "Sapngan",
      "Tinampo",
    ],
    'Casiguran': [
      "Adovis",
      "Boton",
      "Burgos",
      "Casay",
      "Cawit",
      "Central",
      "Cogon",
      "Colambis",
      "Escuala",
      "Inlagadian",
      "Lungib",
      "Mabini",
      "Ponong",
      "Rizal",
      "San Antonio",
      "San Isidro",
      "San Juan",
      "San Pascual",
      "Santa Cruz",
      "Somal-ot",
      "Tigbao",
      "Timbayog",
      "Tiris",
      "Trece Martirez",
      "Tulay",
    ],
    'Castilla': [
      "Amomonting",
      "Bagalayag",
      "Bagong Sirang",
      "Bonga",
      "Buenavista",
      "Burabod",
      "Caburacan",
      "Canjela",
      "Cogon",
      "Cumadcad",
      "Dangcalan",
      "Dinapa",
      "La Union",
      "Libtong",
      "Loreto",
      "Macalaya",
      "Maracabac",
      "Mayon",
      "Maypangi",
      "Milagrosa",
      "Miluya",
      "Monte Carmelo",
      "Oras",
      "Pandan",
      "Poblacion",
      "Quirapi",
      "Saclayan",
      "Salvacion",
      "San Isidro",
      "San Rafael",
      "San Roque",
      "San Vicente",
      "Sogoy",
      "Tomalaytay",
    ],
    'Donsol': [
      "Alin",
      "Awai",
      "Banban",
      "Bandi",
      "Banuang Gurang",
      "Baras",
      "Bayawas",
      "Bororan Barangay 1",
      "Cabugao",
      "Central Barangay 2",
      "Cristo",
      "Dancalan",
      "De Vera",
      "Gimagaan",
      "Girawan",
      "Gogon",
      "Gura",
      "Juan Adre",
      "Lourdes",
      "Mabini",
      "Malapoc",
      "Malinao",
      "Market Site Barangay 3",
      "New Maguisa",
      "Ogod",
      "Old Maguisa",
      "Orange",
      "Pangpang",
      "Parina",
      "Pawala",
      "Pinamanaan",
      "Poso Poblacion",
      "Punta Waling-Waling Poblacion",
      "Rawis",
      "San Antonio",
      "San Isidro",
      "San Jose",
      "San Rafael",
      "San Ramon",
      "San Vicente",
      "Santa Cruz",
      "Sevilla",
      "Sibago",
      "Suguian",
      "Tagbac",
      "Tinanogan",
      "Tongdol",
      "Tres Marias",
      "Tuba",
      "Tupas",
      "Vinisitahan",
    ],
    'Gubat': [
      "Ariman",
      "Bagacay",
      "Balud del Norte",
      "Balud del Sur",
      "Benguet",
      "Bentuco",
      "Beriran",
      "Buenavista",
      "Bulacao",
      "Cabigaan",
      "Cabiguhan",
      "Carriedo",
      "Casili",
      "Cogon",
      "Cota na Daco",
      "Dita",
      "Jupi",
      "Lapinig",
      "Luna-Candol",
      "Manapao",
      "Manook",
      "Naagtan",
      "Nato",
      "Nazareno",
      "Ogao",
      "Paco",
      "Panganiban",
      "Paradijon",
      "Patag",
      "Payawin",
      "Pinontingan",
      "Rizal",
      "San Ignacio",
      "Sangat",
      "Santa Ana",
      "Tabi",
      "Tagaytay",
      "Tigkiw",
      "Tiris",
      "Togawe",
      "Union",
      "Villareal",
    ],
    'Irosin': [
      "Bacolod",
      "Bagsangan",
      "Batang",
      "Bolos",
      "Buenavista",
      "Bulawan",
      "Carriedo",
      "Casini",
      "Cawayan",
      "Cogon",
      "Gabao",
      "Gulang-Gulang",
      "Gumapia",
      "Liang",
      "Macawayan",
      "Mapaso",
      "Monbon",
      "Patag",
      "Salvacion",
      "San Agustin",
      "San Isidro",
      "San Juan",
      "San Julian",
      "San Pedro",
      "Santo Domingo",
      "Tabon-Tabon",
      "Tinampo",
      "Tongdol",
    ],
    'Juban': [
      "Anog",
      "Aroroy",
      "Bacolod",
      "Binanuahan",
      "Biriran",
      "Buraburan",
      "Calateo",
      "Calmayon",
      "Carohayon",
      "Catanagan",
      "Catanusan",
      "Cogon",
      "Embarcadero",
      "Guruyan",
      "Lajong",
      "Maalo",
      "North Poblacion",
      "Puting Sapa",
      "Rangas",
      "Sablayan",
      "Sipaya",
      "South Poblacion",
      "Taboc",
      "Tinago",
      "Tughan",
    ],
    'Magallanes': [
      "Aguada Norte",
      "Aguada Sur",
      "Anibong",
      "Bacalon",
      "Bacolod",
      "Banacud",
      "Behia",
      "Biga",
      "Binisitahan del Norte",
      "Binisitahan del Sur",
      "Biton",
      "Bulala",
      "Busay",
      "Caditaan",
      "Cagbolo",
      "Cagtalaba",
      "Cawit Extension",
      "Cawit Proper",
      "Ginangra",
      "Hubo",
      "Incarizan",
      "Lapinig",
      "Magsaysay",
      "Malbog",
      "Pantalan",
      "Pawik",
      "Pili",
      "Poblacion",
      "Salvacion",
      "Santa Elena",
      "Siuton",
      "Tagas",
      "Tulatula Norte",
      "Tulatula Sur",
    ],
    'Matnog': [
      "Balocawe",
      "Banogao",
      "Banuangdaan",
      "Bariis",
      "Bolo",
      "Bon-ot Big",
      "Bon-ot Small",
      "Cabagahan",
      "Calayuan",
      "Calintaan",
      "Caloocan",
      "Calpi",
      "Camachiles",
      "Camcaman",
      "Coron-coron",
      "Culasi",
      "Gadgaron",
      "Genablan Occidental",
      "Genablan Oriental",
      "Hidhid",
      "Laboy",
      "Lajong",
      "Mambajog",
      "Manjunlad",
      "Manurabi",
      "Naburacan",
      "Paghuliran",
      "Pangi",
      "Pawa",
      "Poropandan",
      "Santa Isabel",
      "Sinalmacan",
      "Sinang-atan",
      "Sinibaran",
      "Sisigon",
      "Sua",
      "Sulangan",
      "Tablac",
      "Tabunan",
      "Tugas",
    ],
    'Pilar': [
      "Abas",
      "Abucay",
      "Bantayan",
      "Banuyo",
      "Bayasong",
      "Bayawas",
      "Binanuahan",
      "Cabiguan",
      "Cagdongon",
      "Calongay",
      "Calpi",
      "Catamlangan",
      "Comapo-capo",
      "Danlog",
      "Dao",
      "Dapdap",
      "Del Rosario",
      "Esmerada",
      "Esperanza",
      "Ginablan",
      "Guiron",
      "Inang",
      "Inapugan",
      "Leona",
      "Lipason",
      "Lourdes",
      "Lubiano",
      "Lumbang",
      "Lungib",
      "Mabanate",
      "Malbog",
      "Marifosque",
      "Mercedes",
      "Migabod",
      "Naspi",
      "Palanas",
      "Pangpang",
      "Pinagsalog",
      "Pineda",
      "Poctol",
      "Pudo",
      "Putiao",
      "Sacnangan",
      "Salvacion",
      "San Antonio (Millabas)",
      "San Antonio (Sapa)",
      "San Jose",
      "San Rafael",
      "Santa Fe",
    ],
    'Prieto Diaz': [
      "Brillante",
      "Bulawan",
      "Calao",
      "Carayat",
      "Diamante",
      "Gogon",
      "Lupi",
      "Maningcay de Oro",
      "Manlabong",
      "Perlas",
      "Quidolog",
      "Rizal",
      "San Antonio",
      "San Fernando",
      "San Isidro",
      "San Juan",
      "San Rafael",
      "San Ramon",
      "Santa Lourdes",
      "Santo Domingo",
      "Talisayan",
      "Tupaz",
      "Ulag",
    ],
    'Sorsogon City': [
      "Abuyog",
      "Almendras-Cogon",
      "Balete",
      "Balogo (Bacon District)",
      "Balogo (Sorsogon East District)",
      "Barayong",
      "Basud",
      "Bato",
      "Bibincahan",
      "Bitan-o/Dalipay",
      "Bogña",
      "Bon-ot",
      "Bucalbucalan",
      "Buenavista",
      "Buenavista (Bacon District)",
      "Buhatan",
      "Bulabog",
      "Burabod",
      "Cabarbuhan",
      "Cabid-an",
      "Cambulaga",
      "Capuy",
      "Caricaran",
      "Del Rosario",
      "Gatbo",
      "Gimaloto",
      "Guinlajon",
      "Jamislagan",
      "Macabog",
      "Maricrum",
      "Marinas",
      "Osiao",
      "Pamurayan",
      "Pangpang",
      "Panlayaan",
      "Peñafrancia",
      "Piot",
      "Poblacion",
      "Polvorista",
      "Rawis",
      "Rizal",
      "Salog",
      "Salvacion",
      "Salvacion (Bacon District)",
      "Sampaloc",
      "San Isidro",
      "San Isidro (Bacon District)",
      "San Juan (Bacon District)",
      "San Juan (Roro)",
      "San Pascual",
      "San Ramon",
      "San Roque",
      "San Vicente",
      "Santa Cruz",
      "Santa Lucia",
      "Santo Domingo",
      "Santo Niño",
      "Sawanga",
      "Sirangan",
      "Sugod",
      "Sulucan",
      "Talisay",
      "Ticol",
      "Tugos",
    ],
    'Santa Magdalena': [
      "Barangay Poblacion I",
      "Barangay Poblacion II",
      "Barangay Poblacion III",
      "Barangay Poblacion IV",
      "La Esperanza",
      "Peñafrancia",
      "Salvacion",
      "San Antonio",
      "San Bartolome",
      "San Eugenio",
      "San Isidro",
      "San Rafael",
      "San Roque",
      "San Sebastian",
    ],
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _phoneController.text = user.phoneNumber!;
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _birthdayController.dispose();
    _purokController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    DateTime initialDate;

    if (_birthdayController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_birthdayController.text);
      } catch (_) {
        initialDate = DateTime.now().subtract(const Duration(days: 6570));
      }
    } else {
      initialDate = DateTime.now().subtract(const Duration(days: 6570));
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),

      // Calendar only — removes the text/pencil entry mode
      initialEntryMode: DatePickerEntryMode.calendarOnly,

      helpText: 'SELECT DATE OF BIRTH',

      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text =
            '${picked.year}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _onSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Authentication session lost. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _profileService.updateProfile(
        uid: user.uid,
        phoneNumber: _phoneController.text.trim(),
        birthday: _birthdayController.text.trim(),
        nationality: _selectedNationality,
        province: _selectedProvince,
        municipality: _selectedMunicipality,
        barangay: _selectedBarangay,
        purok: _purokController.text.trim().isEmpty
            ? null
            : _purokController.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to save profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header Block
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_pin_rounded,
                        size: 48,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Complete Your Profile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please provide your details below to finalize your account setup.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Personal Details Section
                const _SectionTitle('Personal Details'),
                const SizedBox(height: 12),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Date of Birth *'),
                    TextFormField(
                      controller: _birthdayController,
                      readOnly: true,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      onTap: () => _selectDateOfBirth(context),
                      decoration: _inputDecoration('YYYY-MM-DD').copyWith(
                        suffixIcon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Date of Birth is required'
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nationality Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Nationality *'),
                    DropdownButtonFormField<String>(
                      value: _selectedNationality,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      items: _nationalityOptions.map((String nationality) {
                        return DropdownMenuItem<String>(
                          value: nationality,
                          child: Text(
                            nationality,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedNationality = newValue;
                          });
                        }
                      },
                      decoration: _inputDecoration('Select Nationality'),
                      validator: (v) =>
                          v == null ? 'Nationality is required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Contact Information Section
                const _SectionTitle('Contact Details'),
                const SizedBox(height: 12),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Phone Number *'),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _inputDecoration('e.g. 09123456789'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Phone Number is required';
                        if (v.trim().length < 10)
                          return 'Enter a valid phone number';
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Address Section
                const _SectionTitle('Address Details'),
                const SizedBox(height: 12),

                // Province Field (Pre-filled / Fixed to Sorsogon with bold text)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Province *'),
                    TextFormField(
                      initialValue: _selectedProvince,
                      enabled: false,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      decoration: _inputDecoration('Province'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Municipality Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Municipality *'),
                    DropdownButtonFormField<String>(
                      value: _selectedMunicipality,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      hint: Text(
                        'Select Municipality',
                        style: GoogleFonts.inter(
                          color: Colors.black.withOpacity(0.35),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      dropdownColor: Colors.white,
                      items: _municipalityBarangays.keys.map((
                        String municipality,
                      ) {
                        return DropdownMenuItem<String>(
                          value: municipality,
                          child: Text(
                            municipality,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedMunicipality = newValue;
                          _selectedBarangay =
                              null; // Reset barangay when municipality changes
                        });
                      },
                      decoration: _inputDecoration('Select Municipality'),
                      validator: (v) =>
                          v == null ? 'Municipality is required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Barangay Dropdown (Depends on selected Municipality)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Barangay *'),
                    DropdownButtonFormField<String>(
                      value: _selectedBarangay,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      hint: Text(
                        _selectedMunicipality == null
                            ? 'Select municipality first'
                            : 'Select Barangay',
                        style: GoogleFonts.inter(
                          color: Colors.black.withOpacity(0.35),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      dropdownColor: Colors.white,
                      items: _selectedMunicipality == null
                          ? []
                          : _municipalityBarangays[_selectedMunicipality]!.map((
                              String barangay,
                            ) {
                              return DropdownMenuItem<String>(
                                value: barangay,
                                child: Text(
                                  barangay,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                      onChanged: _selectedMunicipality == null
                          ? null
                          : (String? newValue) {
                              setState(() {
                                _selectedBarangay = newValue;
                              });
                            },
                      decoration: _inputDecoration('Select Barangay'),
                      validator: (v) =>
                          v == null ? 'Barangay is required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Purok Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Purok / Street / Zone (Optional)'),
                    TextFormField(
                      controller: _purokController,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _inputDecoration('e.g. Purok 3'),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSaveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Save & Proceed to Verification',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.black.withOpacity(0.35)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final bool isRequired = text.endsWith('*');
    final String displayText = isRequired
        ? text.substring(0, text.length - 1).trim()
        : text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: displayText,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
          children: [
            if (isRequired)
              TextSpan(
                text: ' *',
                style: GoogleFonts.inter(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
