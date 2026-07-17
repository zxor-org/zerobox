#include "my_application.h"

namespace {

void IgnoreHeadlessAtkCritical(const gchar*,
                               GLogLevelFlags,
                               const gchar*,
                               gpointer) {}

}  // namespace

int main(int argc, char** argv) {
  gboolean no_gui = FALSE;
  gboolean secondary_window = FALSE;
  for (int index = 1; index < argc; index++) {
    if (g_strcmp0(argv[index], "--nogui") == 0) {
      no_gui = TRUE;
    }
    if (g_strcmp0(argv[index], "--window") == 0) {
      secondary_window = TRUE;
    }
  }
  if (no_gui) {
    // A headless process has no accessibility tree to export. Starting the
    // AT-SPI bridge for its never-shown Flutter view causes an ATK warning.
    g_setenv("NO_AT_BRIDGE", "1", TRUE);
    // FlView unconditionally wires an ATK socket even when no Flutter widget
    // tree is rendered. atk_plug_get_id() is null in this headless case, which
    // emits a harmless critical for every short-lived CLI invocation.
    g_log_set_handler("Atk", G_LOG_LEVEL_CRITICAL,
                      IgnoreHeadlessAtkCritical, nullptr);
  }
  g_autoptr(MyApplication) app =
      my_application_new(no_gui || secondary_window);
  return g_application_run(G_APPLICATION(app), argc, argv);
}
