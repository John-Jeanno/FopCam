from django import template

register = template.Library()

@register.simple_tag
def filter_choices(cl, spec):
    """Return the list of choices for a filter spec using the changelist."""
    return list(spec.choices(cl))
