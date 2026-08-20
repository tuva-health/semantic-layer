{% macro load_semantic_layer_seed(object_name) %}
  {% if var('_semantic_layer_use_legacy_seed_assets', false) | as_bool %}
    {{ return(the_tuva_project.load_seed(
        the_tuva_project.get_package_seed_uri('value-sets', '1.0.0'),
        object_name,
        true,
        true,
        true
    )) }}
  {% endif %}

  {{ return(the_tuva_project.load_package_seed(
      'semantic_layer',
      'semantic-layer',
      object_name,
      true,
      true,
      true
  )) }}
{% endmacro %}
