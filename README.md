## Sources

- (wiz-sec-research)[https://github.com/wiz-sec-public/wiz-research-iocs/blob/main/reports/shai-hulud-2-packages.csv?plain=1]

## How?

`cd` into the root of the repository you want to scan and call `scripts/al-gaib.sh`. Cross your fingers and check the generated report once the scan finishes.

Besides this scanner, don't forget to:

- Audit all workflows, especially the ones added recently.
- Look for suspicious script steps (curl, wget, base64 blobs, secret exfiltration).
- Rotate as many PATs as possible.
- Search the organization for repos named or containing Shai-Hulud.
- GitHub “Actions → Runs” you didn’t trigger.
- Check the GitHub audit logs for actions you nor an admin did take.
- Enforce 2FA wherever possible.
