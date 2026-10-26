# Folder Backdrop Feedback

Status: APPROVED_IMPLEMENTATION_CONTRACT, 2026-10-16
User decision: Remove whole-background dimming; retain panel motion and layout.

User attributes perceived opening black shadow to whole-background dimming, rather than a captured extra black frame. This is human perception evidence, not a high-speed compositing trace.

Recommended bounded visual revision: remove whole-launcher dimming while retaining the accepted panel layout and existing panel entrance/exit motion. Keep the modal overlay hit-testing/dismissal region intact, but transparent outside the opaque folder panel. Preserve panel contrast/opacity and Reduce Motion behavior; do not change wallpaper, icon layout, input routing, application order or persistence. Test normal, Reduce Transparency and Increase Contrast combinations, title editing and move-out/exit lifecycle; compare user-visible opening perception separately.

Alternative: retain current dimming and finish the independent input-route repair first. User choice was requested asynchronously; no visual implementation is authorized by this proposal alone.

## Approved decision (supersedes pending language above)
User selected remove-background-dimming on 2026-10-16. The exterior overlay is clear under normal, Reduce Transparency and Increase Contrast policies; accessibility material treatment remains on the opaque panel itself. Modal hit testing/dismissal and focus ownership remain unchanged. Do not replace the dim with another full-window fade/tint. Prior alternative and pending text above are historical proposal context only.
