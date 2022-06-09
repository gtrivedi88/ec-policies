package checks

import future.keywords.in

# Required annotations on policy rules
required_annotations := {
	"title",
	"description",
	"custom.short_name",
	"custom.failure_msg",
}

# returns Rego files corresponding to policy rules
policy_rule_files(namespaces) = result {
	result := {rule |
		namespaces[n]
		startswith(n, "data.policy") # look only in the policy namespace
		rule := {"namespace": n, "files": {file |
			file := namespaces[n][_]
			not endswith(file, "_test.rego") # disregard test Rego files
		}}
	}
}

# for annotations defined as:
# {
#   "<ann>": "..."
# }
# return set with single element "<ann>"
flat(annotation_name, annotation_definition) = result {
	is_string(annotation_definition)
	result := {annotation_name}
}

# for annotations defined as:
# {
#   "<ann1>": {
#     "<ann2>": "...",
#     "<ann3>": "..."
#  }
# return set with elements "<ann1>.<ann2>" and "<ann1>.<ann3>"
flat(annotation_name, annotation_definition) = result {
	is_object(annotation_definition)
	result := {x |
		annotation_definition[nested_name]
		x := concat(".", [annotation_name, nested_name])
	}
}

# Validates that the policy rules have all required annotations
violation[msg] {
	policy_files := policy_rule_files(input.namespaces)[_]

	some file in policy_files.files
	annotation := input.annotations[_]

	# just examine Rego files that declare policies
	annotation.location.file == file

	# ... and ignore non-rule annotations, e.g. package, document.
	annotation.annotations.scope == "rule"

	# gather all annotations in a dotted format (e.g. "custom.short_name")
	declared_annotations := union({a |
		annotation.annotations[x]
		a := flat(x, annotation.annotations[x])
	})

	# what required annotations are missing
	missing_annotations := required_annotations - declared_annotations

	# if we have any?
	count(missing_annotations) > 0

	msg := sprintf("ERROR: Missing annotation(s) %s at %s:%d", [concat(", ", missing_annotations), file, annotation.location.row])
}
