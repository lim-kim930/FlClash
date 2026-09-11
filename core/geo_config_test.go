package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/metacubex/mihomo/component/geodata"
	"github.com/metacubex/mihomo/component/geodata/router"
	"github.com/metacubex/mihomo/component/updater"
	"github.com/metacubex/mihomo/constant"
	"google.golang.org/protobuf/proto"
)

func TestBaseConfigGeoDownloads(t *testing.T) {
	if home := os.Getenv("FLCLASH_GEO_CONFIG_TEST_HOME"); home != "" {
		runBaseConfigGeoDownloads(t, home)
		return
	}

	var mu sync.Mutex
	var requests []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		requests = append(requests, r.URL.Path)
		mu.Unlock()
		data, err := proto.Marshal(&router.GeoSiteList{
			Entry: []*router.GeoSite{{
				CountryCode: "cn",
				Domain: []*router.Domain{{
					Type:  router.Domain_Full,
					Value: strings.ReplaceAll(strings.Trim(r.URL.Path, "/"), "/", "."),
				}},
			}},
		})
		if err != nil {
			t.Errorf("encode geosite fixture: %v", err)
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		_, _ = w.Write(data)
	}))
	t.Cleanup(server.Close)

	fixture, err := os.ReadFile(filepath.Join("..", "test", "fixtures", "geo_base_config.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	home := t.TempDir()
	configPath := filepath.Join(home, "config.yaml")
	contents := strings.ReplaceAll(string(fixture), "http://geo.test", server.URL)
	if err := os.WriteFile(configPath, []byte(contents), 0o600); err != nil {
		t.Fatal(err)
	}

	// A full apply owns process-wide mihomo state; fresh processes also verify
	// that the saved config, rather than an in-memory URL, survives restart.
	for _, phase := range []string{"edits", "restart"} {
		t.Run(phase, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()
			command := exec.CommandContext(ctx, os.Args[0], "-test.run=^TestBaseConfigGeoDownloads$")
			command.Env = append(os.Environ(),
				"FLCLASH_GEO_CONFIG_TEST_HOME="+home,
				"FLCLASH_GEO_CONFIG_TEST_PHASE="+phase,
			)
			if output, err := command.CombinedOutput(); err != nil {
				t.Fatalf("Core %s: %v\n%s", phase, err, output)
			}
		})
	}

	mu.Lock()
	defer mu.Unlock()
	want := []string{"/first/geosite.dat", "/second/geosite.dat", "/second/geosite.dat"}
	if !reflect.DeepEqual(requests, want) {
		t.Errorf("download requests = %v, want %v", requests, want)
	}
}

func runBaseConfigGeoDownloads(t *testing.T, home string) {
	t.Helper()
	if !handleInitClash(&InitParams{HomeDir: home}) {
		t.Fatal("Core initialization failed")
	}
	defer handleShutdown()

	completed := make(chan error, 1)
	updater.GeoUpdateHook = func(_ string, updating, _ bool, err error) {
		if !updating {
			completed <- err
		}
	}
	applyAndDownload := func() {
		t.Helper()
		if message := handleSetupConfig(&SetupParams{}); message != "" {
			t.Fatalf("apply base config: %s", message)
		}
		urls := currentConfig.General.GeoXUrl
		if geodata.GeoSiteUrl() != urls.GeoSite || geodata.GeoIpUrl() != urls.GeoIp ||
			geodata.MmdbUrl() != urls.Mmdb || geodata.ASNUrl() != urls.ASN {
			t.Fatal("the base config did not apply every Geo URL")
		}
		if updater.GeoAutoUpdate() || updater.GeoUpdateInterval() != 48 {
			t.Fatalf("auto update = %v, interval = %d", updater.GeoAutoUpdate(), updater.GeoUpdateInterval())
		}
		if message := handleUpdateGeoData("GEOSITE"); message != "" {
			t.Fatalf("request geosite update: %s", message)
		}
		select {
		case err := <-completed:
			if err != nil {
				t.Fatalf("download geosite: %v", err)
			}
		case <-time.After(5 * time.Second):
			t.Fatal("geosite update did not finish")
		}
		deadline := time.Now().Add(time.Second)
		for !claimGeoUpdate("GEOSITE") {
			if time.Now().After(deadline) {
				t.Fatal("geosite update did not release its claim")
			}
			time.Sleep(time.Millisecond)
		}
		releaseGeoUpdate("GEOSITE")
		data, err := os.ReadFile(constant.Path.GeoSite())
		if err != nil || len(data) == 0 {
			t.Fatalf("downloaded geosite is missing: %v", err)
		}
	}

	applyAndDownload()
	if os.Getenv("FLCLASH_GEO_CONFIG_TEST_PHASE") == "edits" {
		path := filepath.Join(home, "config.yaml")
		contents, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		contents = []byte(strings.ReplaceAll(string(contents), "/first/geosite.dat", "/second/geosite.dat"))
		if err := os.WriteFile(path, contents, 0o600); err != nil {
			t.Fatal(err)
		}
		applyAndDownload()
	}
}
