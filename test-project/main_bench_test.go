package main

import (
	"net/http/httptest"
	"testing"
)

func BenchmarkHealth(b *testing.B) {
	srv := NewServer(20)
	mux := newTestMux(srv)

	b.ReportAllocs()
	for b.Loop() {
		req := httptest.NewRequest("GET", "/health", nil)
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, req)
	}
}

func BenchmarkDashboard(b *testing.B) {
	srv := NewServer(20)
	mux := newTestMux(srv)

	b.ReportAllocs()
	for b.Loop() {
		req := httptest.NewRequest("GET", "/", nil)
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, req)
	}
}

func BenchmarkStats(b *testing.B) {
	srv := NewServer(20)
	mux := newTestMux(srv)

	b.ReportAllocs()
	for b.Loop() {
		req := httptest.NewRequest("GET", "/api/stats", nil)
		w := httptest.NewRecorder()
		mux.ServeHTTP(w, req)
	}
}
