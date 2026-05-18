package main

import (
	"embed"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"runtime"
	"slices"
	"sync"
	"time"
)

//go:embed dashboard.html
var dashboardHTML embed.FS

// Server holds the HTTP server state.
type Server struct {
	mu         sync.RWMutex
	reqCount   int64
	startTime  time.Time
	activities []Activity
	maxAct     int
}

// Activity represents a logged request event.
type Activity struct {
	Time    time.Time `json:"time"`
	Method  string    `json:"method"`
	Path    string    `json:"path"`
	Status  int       `json:"status"`
	Latency string    `json:"latency"`
}

// NewServer creates a new Server.
func NewServer(maxActivities int) *Server {
	return &Server{
		startTime: time.Now(),
		maxAct:    maxActivities,
	}
}

func (s *Server) logActivity(method, path string, status int, d time.Duration) {
	s.mu.Lock()
	if len(s.activities) >= s.maxAct {
		s.activities = s.activities[1:]
	}
	s.activities = append(s.activities, Activity{
		Time:    time.Now(),
		Method:  method,
		Path:    path,
		Status:  status,
		Latency: d.Round(time.Microsecond).String(),
	})
	s.mu.Unlock()
}

// Stats is returned by /api/stats.
type Stats struct {
	Uptime      string `json:"uptime"`
	GoVersion   string `json:"go_version"`
	NumGoroutine int   `json:"num_goroutine"`
	MemAllocMB  float64 `json:"mem_alloc_mb"`
	ReqCount    int64  `json:"req_count"`
}

func (s *Server) collectStats() Stats {
	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)

	s.mu.RLock()
	uptime := time.Since(s.startTime).Round(time.Second).String()
	count := s.reqCount
	s.mu.RUnlock()

	return Stats{
		Uptime:       uptime,
		GoVersion:    runtime.Version(),
		NumGoroutine: runtime.NumGoroutine(),
		MemAllocMB:   float64(mem.Alloc) / 1_048_576,
		ReqCount:     count,
	}
}

func (s *Server) collectActivities() []Activity {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return slices.Clone(s.activities)
}

// middleware wraps a handler with request logging.
func (s *Server) middleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Increment request count before handler runs so handlers can see it.
		s.mu.Lock()
		s.reqCount++
		s.mu.Unlock()

		// Use a response wrapper to capture status code.
		rw := &responseWriter{ResponseWriter: w, status: http.StatusOK}
		next(rw, r)

		latency := time.Since(start)
		s.logActivity(r.Method, r.URL.Path, rw.status, latency)

		slog.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rw.status,
			"latency", latency.Round(time.Microsecond).String(),
		)
	}
}

type responseWriter struct {
	http.ResponseWriter
	status int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.status = code
	rw.ResponseWriter.WriteHeader(code)
}

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	srv := NewServer(20)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /", srv.middleware(srv.handleDashboard))
	mux.HandleFunc("GET /health", srv.middleware(srv.handleHealth))
	mux.HandleFunc("GET /api/stats", srv.middleware(srv.handleStats))
	mux.HandleFunc("GET /api/activities", srv.middleware(srv.handleActivities))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	slog.Info("dashboard server starting", "port", port, "go", runtime.Version())
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}

func (s *Server) handleDashboard(w http.ResponseWriter, r *http.Request) {
	data, err := dashboardHTML.ReadFile("dashboard.html")
	if err != nil {
		http.Error(w, "dashboard not found", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(data)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (s *Server) handleStats(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(s.collectStats())
}

func (s *Server) handleActivities(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(s.collectActivities())
}
