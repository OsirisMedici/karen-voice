import { useTranslation } from "react-i18next";
import { openUrl } from "@tauri-apps/plugin-opener";

const UpdateChecker = ({ className = "" }: { className?: string }) => {
  const { t } = useTranslation();
  return (
    <button
      type="button"
      className={`hover:underline ${className}`}
      onClick={() =>
        void openUrl("https://github.com/OsirisMedici/karen-voice/releases")
      }
    >
      {t("settings.about.downloadReleases")}
    </button>
  );
};
export default UpdateChecker;
