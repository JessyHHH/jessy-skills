package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthEndpoint(t *testing.T) {
	srv := NewServer(20)
	mux := newTestMux(srv)

	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var resp map[string]string
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode JSON: %v", err)
	}
	if resp["status"] != "ok" {
		t.Fatalf("expected status=ok, got %q", resp["status"])
	}
}

func TestDashboardServesHTML(t *testing.T) {
	srv := NewServer(20)
	mux := newTestMux(srv)

	req := httptest.NewRequest("GET", "/", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}
	ct := w.Header().Get("Content-Type")
	if !strings.Contains(ct, "text/html") {
		t.Fatalf("expected text/html, got %q", ct)
	}
	if !strings.Contains(w.Body.String(), "<!DOCTYPE html>") {
		t.Fatal("response should contain HTML doctype")
	}
}

func TestStatsEndpoint(t *testing.T) {
	srv := NewServer(20)
	mux := newTestMux(srv)

	req := httptest.NewRequest("GET", "/api/stats", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var stats Stats
	if err := json.NewDecoder(w.Body).Decode(&stats); err != nil {
		t.Fatalf("failed to decode JSON: %v", err)
	}

	// Verify all fields are populated.
	if stats.GoVersion == "" {
		t.Fatal("go_version should not be empty")
	}
	if stats.Uptime == "" {
		t.Fatal("uptime should not be empty")
	}
	if stats.ReqCount < 1 {
		t.Fatalf("req_count should be at least 1 (this request), got %d", stats.ReqCount)
	}
}

func TestActivitiesTracking(t *testing.T) {
	srv := NewServer(20)
	mux := newTestMux(srv)

	// Make several requests.
	paths := []string{"/health", "/api/stats", "/health", "/api/activities"}
	for _, p := range paths {
		req := httptest.NewRequest("GET", p, nil)
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, req)
	}

	// Fetch activities.
	req := httptest.NewRequest("GET", "/api/activities", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	var activities []Activity
	if err := json.NewDecoder(w.Body).Decode(&activities); err != nil {
		t.Fatalf("failed to decode JSON: %v", err)
	}

	// We made 4 requests + this one = 5; all should be tracked.
	if len(activities) < 4 {
		t.Fatalf("expected at least 4 activities, got %d", len(activities))
	}
}

func TestConcurrentAccess(t *testing.T) {
	ctx := t.Context()
	srv := NewServer(20)
	mux := newTestMux(srv)

	done := make(chan struct{})
	for range 10 {
		go func() {
			defer func() { done <- struct{}{} }()
			for range 50 {
				req := httptest.NewRequest("GET", "/health", nil)
				w := httptest.NewRecorder()
				mux.ServeHTTP(w, req)
				if w.Code != http.StatusOK {
					t.Errorf("concurrent request failed with %d", w.Code)
				}
			}
		}()
	}

	for range 10 {
		select {
		case <-done:
		case <-ctx.Done():
			t.Fatal("timed out waiting for goroutines")
		}
	}
}

// newTestMux creates a mux with the same routes as main, for testing.
func newTestMux(srv *Server) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /", srv.middleware(srv.handleDashboard))
	mux.HandleFunc("GET /health", srv.middleware(srv.handleHealth))
	mux.HandleFunc("GET /api/stats", srv.middleware(srv.handleStats))
	mux.HandleFunc("GET /api/activities", srv.middleware(srv.handleActivities))
	return mux
}
