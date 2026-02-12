.PHONY: demo demo-windows ui-demo ui-demo-windows clean

demo:
	bash scripts/demo.sh

demo-windows:
	powershell -ExecutionPolicy Bypass -File scripts/demo.ps1

ui-demo:
	bash scripts/ui_demo.sh

ui-demo-windows:
	powershell -ExecutionPolicy Bypass -File scripts/ui_demo.ps1

clean:
	docker-compose down
