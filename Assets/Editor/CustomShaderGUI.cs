using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class CustomShaderGUI : ShaderGUI
{
    Object[] materials;
	MaterialProperty[] properties;

    enum ShadowMode { On, Clip, Dither, Off }
    ShadowMode Shadows {
		set {
			if (SetProperty("_Shadows", (float)value)) {
				SetKeyword("_SHADOWS_CLIP", value == ShadowMode.Clip);
				SetKeyword("_SHADOWS_DITHER", value == ShadowMode.Dither);
			}
		}
	}

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
		EditorGUI.BeginChangeCheck();
		base.OnGUI(materialEditor, properties);
		materials = materialEditor.targets;
		this.properties = properties;

		if(EditorGUI.EndChangeCheck())
		{
			SetShadowCasterPass();
		}

		EditorGUILayout.Space();
	}

    void SetShadowCasterPass()
	{
		MaterialProperty shadows = FindProperty("_Shadows", properties, false);
		if (shadows == null || shadows.hasMixedValue) {
			return;
		}
		bool enabled = shadows.floatValue < (float)ShadowMode.Off;
		foreach (Material m in materials) {
			m.SetShaderPassEnabled("ShadowCaster", enabled);
		}
	}
    
    bool SetProperty(string name, float value)
	{
		MaterialProperty property = FindProperty(name, properties, false);
		if (property != null) {
			property.floatValue = value;
			return true;
		}
		return false;
	}

	void SetKeyword(string keyword, bool enabled)
	{
		if(enabled)
		{
			foreach(Material m in materials)
			{
				m.EnableKeyword(keyword);
			}
		}
		else
		{
			foreach(Material m in materials)
			{
				m.DisableKeyword(keyword);
			}
		}
	}
}
