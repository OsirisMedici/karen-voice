import type { CSSProperties } from "react";
import { useTranslation } from "react-i18next";
import VoiceMark from "./VoiceMark";

const VoiceWordmark = ({
  width = 200,
  height,
  className,
}: {
  width?: number;
  height?: number;
  className?: string;
}) => {
  const { t } = useTranslation();
  return (
    <div
      className={className}
      aria-label={t("brand.fullName")}
      style={
        {
          width,
          height,
          display: "flex",
          alignItems: "center",
          gap: width * 0.07,
        } as CSSProperties
      }
    >
      <span
        style={{
          color: "var(--color-logo-primary)",
          display: "flex",
          flexShrink: 0,
        }}
      >
        <VoiceMark width={width * 0.24} height={width * 0.24} />
      </span>
      <span
        style={{
          fontSize: width * 0.15,
          fontWeight: 650,
          lineHeight: 1.05,
          letterSpacing: "-0.04em",
        }}
      >
        {t("brand.name")}
        <br />
        <span style={{ fontWeight: 450 }}>{t("brand.capability")}</span>
      </span>
    </div>
  );
};
export default VoiceWordmark;
