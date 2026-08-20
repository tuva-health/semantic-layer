{% macro load_semantic_layer_seed(object_name) %}
  {{ return(the_tuva_project.load_package_seed(
      'semantic_layer',
      'semantic-layer',
      object_name,
      true,
      true,
      true
  )) }}
{% endmacro %}
