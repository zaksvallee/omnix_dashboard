-- Rename Zara capability footfall_count → peak_occupancy and the underlying
-- data source cv_pipeline_footfall → cv_pipeline_occupancy. The tool only ever
-- returned peak occupancy from site_occupancy_sessions.peak_detected; the
-- previous "footfall" naming was retail visitor-counting language and didn't
-- match what the data measures. New naming is honest top-to-bottom.

update public.zara_capabilities
set
  capability_key = 'peak_occupancy',
  display_name = 'Peak Occupancy',
  upsell_blurb = 'Peak occupancy needs the CV pipeline occupancy feed activated for this site. I can flag that through your account manager if helpful.',
  requires_data_source = 'cv_pipeline_occupancy',
  updated_at = now()
where capability_key = 'footfall_count';

update public.client_data_sources
set
  data_source_key = 'cv_pipeline_occupancy',
  updated_at = now()
where data_source_key = 'cv_pipeline_footfall';
