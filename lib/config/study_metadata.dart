/// Metadata for each flood study area.
///
/// Report URLs are stubs — update with real URLs when available.
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

  static const _base =
      'https://wcma.vic.gov.au/wp-content/uploads/2022/05/';

  // TODO(arif): Replace stub report URLs with real ones.
  static final Map<String, StudyInfo> studies = {
    'Concongella_2015': StudyInfo(
      displayName: 'Concongella Creek Flood Investigation',
      completionYear: 2015,
      reportUrl: '${_base}ConcongeFIFinalReport.pdf',
      layers100yr: const ['Concongella_100y_d_Max'],
    ),
    'Dunmunkle_2017': StudyInfo(
      displayName: 'Dunmunkle Creek Flood Investigation',
      completionYear: 2017,
      reportUrl: '${_base}DunmunkleFIFinalReport.pdf',
      layers100yr: const ['Dunm17RvDepthARI100'],
    ),
    'HallsGap_2017': StudyInfo(
      displayName: 'Halls Gap Flood Investigation',
      completionYear: 2017,
      reportUrl: '${_base}HallsGapFIFinalReport.pdf',
      layers100yr: const ['HGAP17RvDepthARI100'],
    ),
    'HorshamWartook_2017': StudyInfo(
      displayName: 'Horsham and Wartook Valley Flood Investigation',
      completionYear: 2019,
      reportUrl: '${_base}HorshamWartookFIFinalReport.pdf',
      layers100yr: const ['Hors19RvDepthARI100'],
    ),
    'MountWilliam_2014': StudyInfo(
      displayName: 'Mount William Creek Flood Investigation',
      completionYear: 2014,
      reportUrl: '${_base}MountWilliamFIFinalReport.pdf',
      layers100yr: const ['MTW_E01_100Y_050_D_MAX'],
    ),
    'Natimuk_2013': StudyInfo(
      displayName: 'Natimuk Catchment Flood Investigation',
      completionYear: 2013,
      reportUrl: '${_base}NatimukFIFinalReport.pdf',
      layers100yr: const ['dep_100y'],
    ),
    'Stawell_2024': StudyInfo(
      displayName: 'Stawell Flood Investigation',
      completionYear: 2024,
      reportUrl: '${_base}StawellFIFinalReport.pdf',
      layers100yr: const ['Stawell24RvDepthARI100', 'StawellG24RvDepthARI100'],
    ),
    'UpperWimmera_2014': StudyInfo(
      displayName: 'Upper Wimmera Flood Investigation',
      completionYear: 2014,
      reportUrl: '${_base}UpperWimmeraFIFinalReport.pdf',
      layers100yr: const ['UW_E01_100y_052_D_Max_g007.50'],
    ),
    'WarracknabealBrim_2016': StudyInfo(
      displayName: 'Warracknabeal and Brim Flood Investigation',
      completionYear: 2016,
      reportUrl: '${_base}WarracknabealBrimFIFinalReport.pdf',
      layers100yr: const ['WaBr15Dep100'],
    ),
    'WimmeraRiverYarriambiackCreek_2010': StudyInfo(
      displayName: 'Wimmera River and Yarriambiack Creek Flood Investigation',
      completionYear: 2010,
      reportUrl:
          '${_base}WimmeraRiverYarriambiackCreekFIFinalReport.pdf',
      layers100yr: const ['100y_existing_flood_depths'],
    ),
  };
}
