/// Metadata for each flood study area.
///
class StudyInfo {
  const StudyInfo({
    required this.displayName,
    required this.completionYear,
    required this.reportUrl,
    required this.layers100yr,
  });

  final String displayName;
  final int completionYear;
  final String reportUrl;
  final List<String> layers100yr;
}

class StudyMetadata {
  StudyMetadata._();

  static final Map<String, StudyInfo> studies = {
    'Concongella_2015': StudyInfo(
      displayName: 'Concongella',
      completionYear: 2015,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2022/05/concongella-ck-regional-flood-mapping-stage-1-draft.pdf',
      layers100yr: const ['Concongella_100y_d_Max'],
    ),
    'Dunmunkle_2017': StudyInfo(
      displayName: 'Dunmunkle',
      completionYear: 2017,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2022/05/dunmunkle-creek-fi_report_lr.pdf',
      layers100yr: const ['Dunm17RvDepthARI100'],
    ),
    'HallsGap_2017': StudyInfo(
      displayName: 'Halls Gap',
      completionYear: 2017,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2022/05/4148-01r04v04_halls_gap_final_report.pdf',
      layers100yr: const ['HGAP17RvDepthARI100'],
    ),
    'HorshamWartook_2017': StudyInfo(
      displayName: 'Horsham Wartook',
      completionYear: 2019,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2022/05/HorshamWartookFIFinalReport.pdf',
      layers100yr: const ['Hors19RvDepthARI100'],
    ),
    'MountWilliam_2014': StudyInfo(
      displayName: 'Mount William',
      completionYear: 2014,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2022/05/mt-william-ck-flood-investigation-r-m20045-007-01_lr.pdf',
      layers100yr: const ['MTW_E01_100Y_050_D_MAX'],
    ),
    'Natimuk_2013': StudyInfo(
      displayName: 'Natimuk',
      completionYear: 2013,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2022/05/flood-investigation-natimuk.pdf',
      layers100yr: const ['dep_100y'],
    ),
    'Stawell_2024': StudyInfo(
      displayName: 'Stawell',
      completionYear: 2024,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2025/01/R06-Stawell-Flood-Investigation-Final-Study-Report-v02.pdf',
      layers100yr: const ['Stawell24RvDepthARI100', 'StawellG24RvDepthARI100'],
    ),
    'UpperWimmera_2014': StudyInfo(
      displayName: 'Upper Wimmera',
      completionYear: 2014,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2022/05/upper-wimmera-flood-investigation-r-m8460-009-01_lr.pdf',
      layers100yr: const ['UW_E01_100y_052_D_Max_g007_50'],
    ),
    'WarracknabealBrim_2016': StudyInfo(
      displayName: 'Warracknabeal Brim',
      completionYear: 2016,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2022/05/flood-investigation-warracknabeal-and-brim.pdf',
      layers100yr: const ['WaBr15Dep100'],
    ),
    'WimmeraRiverYarriambiackCreek_2010': StudyInfo(
      displayName: 'Wimmera River Yarriambiack Creek',
      completionYear: 2010,
      reportUrl:
          'https://wcma.vic.gov.au/wp-content/uploads/2022/05/flood-investigation-wimmera-river-amp-yarriambiack-creek-flow-modelling.pdf',
      layers100yr: const ['l_100y_existing_flood_depths'],
    ),
  };
}
