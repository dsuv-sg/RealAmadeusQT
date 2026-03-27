using UnityEngine;
using UnityEditor;
using TMPro;

public class DumpCredits
{
    [MenuItem("Tools/Dump Credits Properties")]
    public static void Dump()
    {
        Object obj = EditorUtility.InstanceIDToObject(62220);
        if (obj is GameObject go)
        {
            var rt = go.GetComponent<RectTransform>();
            var tmp = go.GetComponent<TextMeshProUGUI>();
            if (rt != null)
            {
                Debug.Log($"[CreditsRT] Anchors: Min={rt.anchorMin}, Max={rt.anchorMax}, Pivot={rt.pivot}, SizeDelta={rt.sizeDelta}, AnchoredPos={rt.anchoredPosition}");
            }
            if (tmp != null)
            {
                Debug.Log($"[CreditsTMP] Text='{tmp.text}', FontSize={tmp.fontSize}, Color={tmp.color}, Alignment={tmp.alignment}");
            }
        }
    }
}
