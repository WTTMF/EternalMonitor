use ffmpeg_next::format::Pixel;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum EncoderInput {
    Auto,
    Bgra,
    // AMD BGRA is unsupported in the pinned SDK; see docs/decisions.md.
    #[default]
    Yuv420,
}

impl EncoderInput {
    pub fn from_env(value: &str) -> Option<Self> {
        match value.trim().to_ascii_lowercase().as_str() {
            "auto" => Some(Self::Auto),
            "bgra" => Some(Self::Bgra),
            "yuv420" | "yuv420p" => Some(Self::Yuv420),
            _ => None,
        }
    }
}

pub(super) fn select_input(
    mode: EncoderInput,
    codec_name: &str,
    supported: &[Pixel],
) -> Result<Pixel, String> {
    if codec_name == "libx264" {
        return Ok(Pixel::YUV420P);
    }

    let bgra_format = [Pixel::BGRA, Pixel::BGRZ]
        .into_iter()
        .find(|format| supported.contains(format));

    if matches!(codec_name, "h264_qsv" | "hevc_qsv") {
        if mode == EncoderInput::Bgra {
            return bgra_format.ok_or_else(|| {
                format!(
                    "The selected QSV encoder does not accept BGRA/BGR0 input; supported formats: {supported:?}"
                )
            });
        }
        return supported
            .contains(&Pixel::NV12)
            .then_some(Pixel::NV12)
            .ok_or_else(|| {
                format!(
                    "The selected QSV encoder requires NV12 input; supported formats: {supported:?}"
                )
            });
    }

    if mode == EncoderInput::Yuv420 {
        return Ok(Pixel::YUV420P);
    }
    if let Some(format) = bgra_format {
        return Ok(format);
    }
    if mode == EncoderInput::Bgra {
        Err("The selected encoder does not accept BGRA/BGR0 input".to_string())
    } else {
        Ok(Pixel::YUV420P)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn qsv_uses_nv12_for_auto_and_default_yuv420() {
        let formats = [Pixel::NV12, Pixel::QSV];
        assert_eq!(
            select_input(EncoderInput::Auto, "h264_qsv", &formats),
            Ok(Pixel::NV12)
        );
        assert_eq!(
            select_input(EncoderInput::Yuv420, "h264_qsv", &formats),
            Ok(Pixel::NV12)
        );
        assert_eq!(
            select_input(EncoderInput::Yuv420, "hevc_qsv", &formats),
            Ok(Pixel::NV12)
        );
    }

    #[test]
    fn qsv_rejects_unsupported_inputs_with_format_details() {
        let bgra_error = select_input(EncoderInput::Bgra, "h264_qsv", &[Pixel::NV12]).unwrap_err();
        assert!(bgra_error.contains("BGRA/BGR0"));
        assert!(bgra_error.contains("NV12"));

        let nv12_error = select_input(EncoderInput::Auto, "hevc_qsv", &[Pixel::QSV]).unwrap_err();
        assert!(nv12_error.contains("NV12"));
        assert!(nv12_error.contains("QSV"));
    }

    #[test]
    fn nvenc_amf_and_software_selection_is_unchanged() {
        let formats = [Pixel::YUV420P, Pixel::BGRZ, Pixel::BGRA];
        assert_eq!(
            select_input(EncoderInput::Auto, "h264_nvenc", &formats),
            Ok(Pixel::BGRA)
        );
        assert_eq!(
            select_input(EncoderInput::Auto, "h264_amf", &[Pixel::BGRZ]),
            Ok(Pixel::BGRZ)
        );
        assert_eq!(
            select_input(EncoderInput::Auto, "unknown", &[]),
            Ok(Pixel::YUV420P)
        );
        assert!(select_input(EncoderInput::Bgra, "hevc_amf", &[Pixel::NV12]).is_err());
        assert_eq!(
            select_input(EncoderInput::Bgra, "libx264", &formats),
            Ok(Pixel::YUV420P)
        );
        assert_eq!(
            select_input(EncoderInput::default(), "h264_nvenc", &formats),
            Ok(Pixel::YUV420P)
        );
        assert_eq!(EncoderInput::from_env("BGRA"), Some(EncoderInput::Bgra));
        assert_eq!(EncoderInput::from_env("mistyped"), None);
    }
}
