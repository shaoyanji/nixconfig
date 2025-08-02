package main

import (
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
)

func handleRequest(w http.ResponseWriter, req *http.Request) {
	fmt.Fprintf(w, time.Now().Format(time.DateTime))
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		panic(fmt.Sprintf("environment variable not set: PORT"))
	}
	r := mux.NewRouter()
	r.HandleFunc("/", handleRequest)
	http.Handle("/", r)
	fmt.Println("Backend listening on port " + port)
	http.ListenAndServe(":"+port, nil)
}
