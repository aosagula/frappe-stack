app_name = "cliente_demo"
app_title = "Cliente Demo"
app_publisher = "Agentic4Biz"
app_description = "Personalizaciones del cliente demo"
app_email = "alejandro.sagula@gmail.com"
app_license = "gpl-3.0"

required_apps = ["agentic_base"]

fixtures = [
	{"dt": "Custom Field", "filters": [["module", "=", "Cliente Demo"]]},
]

doc_events = {
	"Item": {
		"validate": "cliente_demo.ncm.validate_item",
	},
}
