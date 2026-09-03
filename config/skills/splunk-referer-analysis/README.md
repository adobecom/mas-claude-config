# Splunk referer analysis — how to get the input

This skill needs a Splunk LANA CSV export for one referer URL. Steps to get it:

1. Open the dashboard: [MS LANA logs](https://splunk-us.corp.adobe.com/en-US/app/app_log_always_never_assume/ms_lana_logs?tab=layout_1&form.global_time.earliest=-4h%40m&form.global_time.latest=now&form.txt_filter=*)
2. From the top-sources panel, pick the referer/page you want to investigate and click it.
3. That opens a Splunk search scoped to that referer's errors — from there, **download report** (CSV).
4. Run the skill with a reference to the downloaded CSV, e.g.:
   ```
   /splunk-referer-analysis path/to/downloaded_report.csv
   ```
