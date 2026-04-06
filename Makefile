run:
	go run main.go
go-lib:
	go mod tidy
mock-run:
	MOCK_USERS=true go run .   
react:
	# npm i install library 
	npm run dev
