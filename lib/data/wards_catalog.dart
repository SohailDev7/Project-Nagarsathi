/// Municipal ward metadata with neighborhood landmarks for the ward selector.
class MunicipalWard {
  const MunicipalWard({
    required this.wardNumber,
    required this.landmarks,
    this.municipality = 'Kathmandu Metropolitan City',
  });

  final int wardNumber;
  final String landmarks;
  final String municipality;

  String get shortLabel => 'Ward $wardNumber';
  String get dropdownLabel => 'Ward $wardNumber — $landmarks';
}

/// Valid Kathmandu Metropolitan City wards (1–32) with recognizable landmarks.
abstract final class WardsCatalog {
  static const List<MunicipalWard> kathmanduWards = [
    MunicipalWard(wardNumber: 1, landmarks: 'Naxal, Durbar Marg, Kamalpokhari'),
    MunicipalWard(wardNumber: 2, landmarks: 'Lazimpat, Lazimpat Chowk'),
    MunicipalWard(wardNumber: 3, landmarks: 'Maharajgunj, Bansbari, Teaching Hospital'),
    MunicipalWard(wardNumber: 4, landmarks: 'Baluwatar, Bishalnagar, Dhumbarahi'),
    MunicipalWard(wardNumber: 5, landmarks: 'Handigaun, Tangal, Bhatbhateni'),
    MunicipalWard(wardNumber: 6, landmarks: 'Boudha, Chabahil, Tinchule'),
    MunicipalWard(wardNumber: 7, landmarks: 'Chabahil, Mitrapark, Kumarigal'),
    MunicipalWard(wardNumber: 8, landmarks: 'Pashupatinath, Gaushala, Jayabageshwori'),
    MunicipalWard(wardNumber: 9, landmarks: 'Sinamangal, Battisputali, Airport Gate'),
    MunicipalWard(wardNumber: 10, landmarks: 'New Baneshwor, Shankhamul, Buddhanagar'),
    MunicipalWard(wardNumber: 11, landmarks: 'Maitighar, Thapathali, Babarmahal'),
    MunicipalWard(wardNumber: 12, landmarks: 'Teku, Pachali, Tripureshwor'),
    MunicipalWard(wardNumber: 13, landmarks: 'Kalimati, Tahachal, Bafal'),
    MunicipalWard(wardNumber: 14, landmarks: 'Kalanki, Kuleshwor, Balkhu'),
    MunicipalWard(wardNumber: 15, landmarks: 'Swayambhu, Dallu, Bijeshwori'),
    MunicipalWard(wardNumber: 16, landmarks: 'Balaju, Nayabazar, Sorhakhutte'),
    MunicipalWard(wardNumber: 17, landmarks: 'Chhetrapati, Dhalko, Khusibu'),
    MunicipalWard(wardNumber: 18, landmarks: 'Nardevi, Bhimsensthan, Raktakali'),
    MunicipalWard(wardNumber: 19, landmarks: 'Maru, Damaitole, Kankeshwori'),
    MunicipalWard(wardNumber: 20, landmarks: 'Bhimsensthan, Chikanmugal, Kohiti'),
    MunicipalWard(wardNumber: 21, landmarks: 'Lagan, Jaisidewal, Yangal'),
    MunicipalWard(wardNumber: 22, landmarks: 'New Road, Sundhara, Te Bahal'),
    MunicipalWard(wardNumber: 23, landmarks: 'Basantapur, Om Bahal, Jhochen'),
    MunicipalWard(wardNumber: 24, landmarks: 'Indrachowk, Makhan, Hanuman Dhoka'),
    MunicipalWard(wardNumber: 25, landmarks: 'Ason, Keltole, Bhotahity'),
    MunicipalWard(wardNumber: 26, landmarks: 'Thamel, Lainchaur, Gongabu'),
    MunicipalWard(wardNumber: 27, landmarks: 'Bhotahity, Mahabouddha, Bir Hospital'),
    MunicipalWard(wardNumber: 28, landmarks: 'Bagbazar, Putalisadak, Bhrikutimandap'),
    MunicipalWard(wardNumber: 29, landmarks: 'Anamnagar, Ghattekulo, Dillibazar'),
    MunicipalWard(wardNumber: 30, landmarks: 'Gyaneshwor, Maitidevi, Ratopul'),
    MunicipalWard(wardNumber: 31, landmarks: 'Shantinagar, Minbhawan, Aloknagar'),
    MunicipalWard(wardNumber: 32, landmarks: 'Koteshwor, Tinkune, Jadibuti'),
  ];

  static MunicipalWard? byNumber(int? wardNumber) {
    if (wardNumber == null) return null;
    for (final ward in kathmanduWards) {
      if (ward.wardNumber == wardNumber) return ward;
    }
    return null;
  }
}
