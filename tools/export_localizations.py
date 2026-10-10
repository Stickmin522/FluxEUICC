from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {
    "en": "values", "zh-CN": "values-zh-rCN", "zh-TW": "values-zh-rTW",
    "ja": "values-ja", "ko": "values-ko", "ar": "values-ar",
    "fr": "values-fr", "de": "values-de", "es": "values-es",
}
KEYS = ["operation_failed", "busy", "interrupted", "invalid_address", "safeguard_enabled",
        "ui_scan", "ui_image", "ui_manual", "ui_continue", "ui_cancel", "ui_done", "ui_empty_notifications",
        "ui_confirm_download", "ui_download_complete", "ui_language", "ui_retry", "ui_copy", "ui_save"]
TEXT = {
    "en": ["Operation failed. Please try again.", "Wait for the current operation to finish.", "Operation interrupted. Read the card status again.", "Enter a valid SM-DP+ server address.", "Allow disabling removable eSIMs in Settings first.", "Scan QR code", "Import from image", "Enter manually", "Continue", "Cancel", "Done", "No notifications", "Confirm download", "eSIM downloaded", "Language", "Try again", "Copy", "Save"],
    "zh-CN": ["操作失败，请重试。", "请等待当前操作完成。", "操作已中断，请重新读取卡片状态。", "请输入有效的 SM-DP+ 服务器地址。", "请先在设置中允许禁用可拆卸 eSIM。", "扫描二维码", "从图片导入", "手动输入", "继续", "取消", "完成", "暂无通知", "确认下载", "eSIM 下载完成", "语言", "重试", "复制", "保存"],
    "zh-TW": ["操作失敗，請重試。", "請等待目前操作完成。", "操作已中斷，請重新讀取卡片狀態。", "請輸入有效的 SM-DP+ 伺服器位址。", "請先在設定中允許停用可拆卸 eSIM。", "掃描 QR 碼", "從圖片匯入", "手動輸入", "繼續", "取消", "完成", "暫無通知", "確認下載", "eSIM 下載完成", "語言", "重試", "複製", "儲存"],
    "ja": ["操作に失敗しました。もう一度お試しください。", "現在の操作が完了するまでお待ちください。", "操作が中断されました。カードの状態を再読み込みしてください。", "有効な SM-DP+ サーバーアドレスを入力してください。", "まず設定で取り外し可能な eSIM の無効化を許可してください。", "QR コードをスキャン", "画像から読み込む", "手動で入力", "続ける", "キャンセル", "完了", "通知はありません", "ダウンロードを確認", "eSIM のダウンロード完了", "言語", "再試行", "コピー", "保存"],
    "ko": ["작업에 실패했습니다. 다시 시도해 주세요.", "현재 작업이 끝날 때까지 기다려 주세요.", "작업이 중단되었습니다. 카드 상태를 다시 읽어 주세요.", "유효한 SM-DP+ 서버 주소를 입력해 주세요.", "먼저 설정에서 탈착식 eSIM 비활성화를 허용해 주세요.", "QR 코드 스캔", "이미지에서 가져오기", "직접 입력", "계속", "취소", "완료", "알림 없음", "다운로드 확인", "eSIM 다운로드 완료", "언어", "다시 시도", "복사", "저장"],
    "ar": ["فشلت العملية. يرجى المحاولة مجددًا.", "انتظر حتى تكتمل العملية الحالية.", "انقطعت العملية. أعد قراءة حالة البطاقة.", "أدخل عنوان خادم SM-DP+ صالحًا.", "اسمح أولًا بتعطيل بطاقات eSIM القابلة للإزالة من الإعدادات.", "مسح رمز QR", "استيراد من صورة", "إدخال يدوي", "متابعة", "إلغاء", "تم", "لا توجد إشعارات", "تأكيد التنزيل", "اكتمل تنزيل eSIM", "اللغة", "إعادة المحاولة", "نسخ", "حفظ"],
    "fr": ["Échec de l’opération. Réessayez.", "Attendez la fin de l’opération en cours.", "Opération interrompue. Relisez l’état de la carte.", "Saisissez une adresse de serveur SM-DP+ valide.", "Autorisez d’abord la désactivation des eSIM amovibles dans les paramètres.", "Scanner un code QR", "Importer une image", "Saisir manuellement", "Continuer", "Annuler", "Terminé", "Aucune notification", "Confirmer le téléchargement", "eSIM téléchargée", "Langue", "Réessayer", "Copier", "Enregistrer"],
    "de": ["Vorgang fehlgeschlagen. Bitte erneut versuchen.", "Warten Sie, bis der aktuelle Vorgang abgeschlossen ist.", "Vorgang unterbrochen. Lesen Sie den Kartenstatus erneut aus.", "Geben Sie eine gültige SM-DP+-Serveradresse ein.", "Erlauben Sie zuerst in den Einstellungen das Deaktivieren entnehmbarer eSIMs.", "QR-Code scannen", "Aus Bild importieren", "Manuell eingeben", "Weiter", "Abbrechen", "Fertig", "Keine Benachrichtigungen", "Download bestätigen", "eSIM heruntergeladen", "Sprache", "Erneut versuchen", "Kopieren", "Speichern"],
    "es": ["La operación ha fallado. Inténtalo de nuevo.", "Espera a que termine la operación actual.", "Operación interrumpida. Vuelve a leer el estado de la tarjeta.", "Introduce una dirección válida del servidor SM-DP+.", "Primero permite desactivar las eSIM extraíbles en Ajustes.", "Escanear código QR", "Importar desde una imagen", "Introducir manualmente", "Continuar", "Cancelar", "Listo", "No hay notificaciones", "Confirmar descarga", "eSIM descargada", "Idioma", "Reintentar", "Copiar", "Guardar"],
}


METHOD_HINTS = {
    "en": ["Paste or type the activation code from your provider.", "Enter the SM-DP+ address and activation details."],
    "zh-CN": ["粘贴或输入运营商提供的激活码。", "填写 SM-DP+ 地址和激活信息。"],
    "zh-TW": ["貼上或輸入電信業者提供的啟用碼。", "填寫 SM-DP+ 位址和啟用資訊。"],
    "ja": ["通信事業者のアクティベーションコードを貼り付けるか入力します。", "SM-DP+ アドレスとアクティベーション情報を入力します。"],
    "ko": ["통신사에서 받은 활성화 코드를 붙여 넣거나 입력하세요.", "SM-DP+ 주소와 활성화 정보를 입력하세요."],
    "ar": ["الصق رمز التفعيل المقدم من شركة الاتصالات أو أدخله.", "أدخل عنوان SM-DP+ وبيانات التفعيل."],
    "fr": ["Collez ou saisissez le code d’activation fourni par votre opérateur.", "Saisissez l’adresse SM-DP+ et les informations d’activation."],
    "de": ["Fügen Sie den Aktivierungscode Ihres Anbieters ein oder geben Sie ihn ein.", "Geben Sie die SM-DP+-Adresse und die Aktivierungsdaten ein."],
    "es": ["Pega o escribe el código de activación de tu operador.", "Introduce la dirección SM-DP+ y los datos de activación."],
}


ICON_TEXT = {
    "en": ["Change icon", "Choose from gallery", "Take a photo", "Restore default icon"],
    "zh-CN": ["更换图标", "从图库选择", "拍摄照片", "恢复默认图标"],
    "zh-TW": ["更換圖示", "從相簿選擇", "拍攝照片", "還原預設圖示"],
    "ja": ["アイコンを変更", "写真から選択", "写真を撮影", "標準のアイコンに戻す"],
    "ko": ["아이콘 변경", "갤러리에서 선택", "사진 촬영", "기본 아이콘으로 복원"],
    "ar": ["تغيير الأيقونة", "اختيار من المعرض", "التقاط صورة", "استعادة الأيقونة الافتراضية"],
    "fr": ["Changer l’icône", "Choisir dans la galerie", "Prendre une photo", "Rétablir l’icône par défaut"],
    "de": ["Symbol ändern", "Aus Galerie auswählen", "Foto aufnehmen", "Standardsymbol wiederherstellen"],
    "es": ["Cambiar icono", "Elegir de la galería", "Tomar una foto", "Restaurar el icono predeterminado"],
}


PROFILE_ACTION_KEYS = ["ui_confirm", "profile_switch", "profile_switch_confirm",
    "profile_disable_confirm", "profile_delete_question", "profile_active_warning", "profile_state_changed"]
PROFILE_ACTION_TEXT = {
    "en": ["Confirm", "Switch", "Switch from “%1$s” to “%2$s”?", "Disable “%s”?",
        "Delete “%s”? This cannot be undone.",
        "Disabling or deleting the active profile on a removable eSIM card may make the card inaccessible.",
        "The active profile has changed. Refresh the list and try again."],
    "zh-CN": ["确认", "切换", "是否从“%1$s”切换为“%2$s”？", "是否禁用“%s”？",
        "是否删除“%s”？此操作无法撤销。", "禁用或删除可插拔 eSIM 卡中已启用的配置文件，可能导致卡片无法访问。",
        "已启用的配置文件发生变化，请刷新列表后重试。"],
    "zh-TW": ["確認", "切換", "是否從「%1$s」切換為「%2$s」？", "是否停用「%s」？",
        "是否刪除「%s」？此操作無法復原。", "停用或刪除可插拔 eSIM 卡中已啟用的設定檔，可能導致卡片無法存取。",
        "已啟用的設定檔已變更，請重新整理清單後再試。"],
    "ja": ["確認", "切り替え", "「%1$s」から「%2$s」に切り替えますか？", "「%s」を無効にしますか？",
        "「%s」を削除しますか？この操作は取り消せません。",
        "取り外し可能な eSIM カードで有効なプロファイルを無効化または削除すると、カードにアクセスできなくなる場合があります。",
        "有効なプロファイルが変更されました。一覧を更新して再度お試しください。"],
    "ko": ["확인", "전환", "“%1$s”에서 “%2$s”(으)로 전환할까요?", "“%s”을(를) 비활성화할까요?",
        "“%s”을(를) 삭제할까요? 이 작업은 되돌릴 수 없습니다.",
        "탈착식 eSIM 카드에서 활성화된 프로필을 비활성화하거나 삭제하면 카드에 접근할 수 없게 될 수 있습니다.",
        "활성 프로필이 변경되었습니다. 목록을 새로고침한 후 다시 시도하세요."],
    "ar": ["تأكيد", "تبديل", "هل تريد التبديل من «%1$s» إلى «%2$s»؟", "هل تريد تعطيل «%s»؟",
        "هل تريد حذف «%s»؟ لا يمكن التراجع عن هذا الإجراء.",
        "قد يؤدي تعطيل الملف النشط أو حذفه على بطاقة eSIM قابلة للإزالة إلى تعذر الوصول إلى البطاقة.",
        "تغير الملف النشط. حدّث القائمة وحاول مرة أخرى."],
    "fr": ["Confirmer", "Basculer", "Passer de « %1$s » à « %2$s » ?", "Désactiver « %s » ?",
        "Supprimer « %s » ? Cette action est irréversible.",
        "La désactivation ou la suppression du profil actif sur une carte eSIM amovible peut rendre la carte inaccessible.",
        "Le profil actif a changé. Actualisez la liste et réessayez."],
    "de": ["Bestätigen", "Wechseln", "Von „%1$s“ zu „%2$s“ wechseln?", "„%s“ deaktivieren?",
        "„%s“ löschen? Diese Aktion kann nicht rückgängig gemacht werden.",
        "Wenn das aktive Profil einer herausnehmbaren eSIM-Karte deaktiviert oder gelöscht wird, kann die Karte unzugänglich werden.",
        "Das aktive Profil hat sich geändert. Aktualisieren Sie die Liste und versuchen Sie es erneut."],
    "es": ["Confirmar", "Cambiar", "¿Cambiar de «%1$s» a «%2$s»?", "¿Desactivar «%s»?",
        "¿Eliminar «%s»? Esta acción no se puede deshacer.",
        "Desactivar o eliminar el perfil activo de una tarjeta eSIM extraíble puede impedir el acceso a la tarjeta.",
        "El perfil activo ha cambiado. Actualiza la lista e inténtalo de nuevo."],
}


def read_values(directory):
    values = {}
    for module in ("app-common", "app-unpriv"):
        for path in sorted((ROOT / module / "src/main/res" / directory).glob("*.xml")):
            for entry in ET.parse(path).getroot():
                if entry.tag != "string":
                    continue
                text = "".join(entry.itertext())
                text = re.sub(r"<[^>]*>", "", text).replace("\\n", "\n").replace("\\'", "'").replace('\\"', '"')
                values[entry.attrib["name"]] = text.strip('"')
    return values


if __name__ == "__main__":
    destination = ROOT / "flutter_ui/assets/i18n"
    destination.mkdir(parents=True, exist_ok=True)
    english = read_values("values")
    for language, directory in LANGUAGES.items():
        values = english | read_values(directory) | dict(zip(KEYS, TEXT[language]))
        values |= dict(zip(["ui_code_hint", "ui_manual_hint"], METHOD_HINTS[language]))
        values |= dict(zip(["ui_change_icon", "ui_icon_gallery", "ui_icon_camera", "ui_icon_reset"], ICON_TEXT[language]))
        values |= dict(zip(PROFILE_ACTION_KEYS, PROFILE_ACTION_TEXT[language]))
        values = {key: re.sub(r"\besim\b", "eSIM", value, flags=re.I) for key, value in values.items()}
        (destination / f"{language}.json").write_text(json.dumps(values, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
