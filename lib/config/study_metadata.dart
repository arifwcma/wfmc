class StudyReports {
  StudyReports._();

  static const Map<String, String> reportUrlByStudyName = {
    'Concongella 2015 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/concongella-ck-regional-flood-mapping-stage-1-draft.pdf',
    'Dunmunkle 2017 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/dunmunkle-creek-fi_report_lr.pdf',
    'Halls Gap 2017 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/4148-01r04v04_halls_gap_final_report.pdf',
    'Horsham Wartook 2019 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/HorshamWartookFIFinalReport.pdf',
    'Lower Wimmera 2016 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/3795-01_r02final_hydrology.pdf',
    'Mt William 2014 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/mt-william-ck-flood-investigation-r-m20045-007-01_lr.pdf',
    'Natimuk 2013 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/flood-investigation-natimuk.pdf',
    'Stawell 2024 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2025/01/R06-Stawell-Flood-Investigation-Final-Study-Report-v02.pdf',
    'Upper Wimmera 2014 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/upper-wimmera-flood-investigation-r-m8460-009-01_lr.pdf',
    'Warracknabeal Brim 2015 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/flood-investigation-warracknabeal-and-brim.pdf',
    'Wimmera River Yarriambiack Creek 2010 Flood Depths':
        'https://wcma.vic.gov.au/wp-content/uploads/2022/05/flood-investigation-wimmera-river-amp-yarriambiack-creek-flow-modelling.pdf',
  };

  static String? reportUrlFor(String studyName) {
    return reportUrlByStudyName[studyName];
  }

  static String displayNameFor(String studyName) {
    const suffix = ' Flood Depths';
    if (studyName.endsWith(suffix)) {
      return studyName.substring(0, studyName.length - suffix.length);
    }
    return studyName;
  }
}
