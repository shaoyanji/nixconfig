package main

import (
	"encoding/csv"
	"fmt"
	"io"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/BurntSushi/toml"
)

type Item struct {
	ID            int64     `json:"id"`
	Source        string    `json:"source"`
	SourceKey     string    `json:"source_key,omitempty"`
	Name          string    `json:"name"`
	Category      string    `json:"category"`
	Location      string    `json:"location"`
	Description   string    `json:"description,omitempty"`
	Manufacturer  string    `json:"manufacturer,omitempty"`
	Model         string    `json:"model,omitempty"`
	Serial        string    `json:"serial,omitempty"`
	PurchaseDate  string    `json:"purchase_date,omitempty"`
	WarrantyUntil string    `json:"warranty_until,omitempty"`
	ValueCents    int64     `json:"value_cents"`
	Currency      string    `json:"currency"`
	Quantity      int       `json:"quantity"`
	URL           string    `json:"url,omitempty"`
	Notes         string    `json:"notes,omitempty"`
	Tags          []string  `json:"tags"`
	Archived      bool      `json:"archived"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
	Snippet       string    `json:"snippet,omitempty"`
}

type itemInput struct {
	Source        string   `json:"source"`
	SourceKey     string   `json:"source_key"`
	Name          string   `json:"name"`
	Category      string   `json:"category"`
	Location      string   `json:"location"`
	Description   string   `json:"description"`
	Manufacturer  string   `json:"manufacturer"`
	Model         string   `json:"model"`
	Serial        string   `json:"serial"`
	PurchaseDate  string   `json:"purchase_date"`
	WarrantyUntil string   `json:"warranty_until"`
	ValueCents    int64    `json:"value_cents"`
	Currency      string   `json:"currency"`
	Quantity      int      `json:"quantity"`
	URL           string   `json:"url"`
	Notes         string   `json:"notes"`
	Tags          []string `json:"tags"`
	Archived      bool     `json:"archived"`
}

type metaEntry struct {
	Name        string    `json:"name"`
	Description string    `json:"description,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	ItemCount   int       `json:"item_count"`
}

type exportBundle struct {
	Version    int         `json:"version"`
	ExportedAt time.Time   `json:"exported_at"`
	Items      []Item      `json:"items"`
	Categories []metaEntry `json:"categories"`
	Locations  []metaEntry `json:"locations"`
	Tags       []metaEntry `json:"tags"`
}

type importResult struct {
	Inserted int      `json:"inserted"`
	Updated  int      `json:"updated"`
	Skipped  int      `json:"skipped"`
	Warnings []string `json:"warnings,omitempty"`
}

var (
	spaceRE   = regexp.MustCompile(`\s+`)
	tagBadRE  = regexp.MustCompile(`[^a-z0-9+#./_-]+`)
	csvFields = []string{"source", "source_key", "name", "category", "location", "description", "manufacturer", "model", "serial", "purchase_date", "warranty_until", "value_cents", "currency", "quantity", "url", "notes", "tags", "archived"}
)

func clean(s string) string { return spaceRE.ReplaceAllString(strings.TrimSpace(s), " ") }

func normalizeTags(tags []string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, tag := range tags {
		for _, part := range strings.Split(tag, ",") {
			part = tagBadRE.ReplaceAllString(strings.ToLower(strings.TrimSpace(part)), "")
			if part != "" && !seen[part] {
				seen[part] = true
				out = append(out, part)
			}
		}
	}
	sort.Strings(out)
	return out
}

func validateItem(input *itemInput) error {
	input.Source = clean(input.Source)
	if input.Source == "" {
		input.Source = "manual"
	}
	input.SourceKey = clean(input.SourceKey)
	input.Name = clean(input.Name)
	if input.Name == "" {
		return fmt.Errorf("name is required")
	}
	if len(input.Name) > 180 {
		return fmt.Errorf("name is too long")
	}
	input.Category = clean(input.Category)
	input.Location = clean(input.Location)
	input.Description = clean(input.Description)
	input.Manufacturer = clean(input.Manufacturer)
	input.Model = clean(input.Model)
	input.Serial = clean(input.Serial)
	input.PurchaseDate = strings.TrimSpace(input.PurchaseDate)
	input.WarrantyUntil = strings.TrimSpace(input.WarrantyUntil)
	input.Currency = strings.ToUpper(strings.TrimSpace(input.Currency))
	if input.Currency == "" {
		input.Currency = "EUR"
	}
	if len(input.Currency) != 3 {
		return fmt.Errorf("currency must be a three-letter code")
	}
	if input.Quantity == 0 {
		input.Quantity = 1
	}
	if input.Quantity < 0 {
		return fmt.Errorf("quantity cannot be negative")
	}
	if input.ValueCents < 0 {
		return fmt.Errorf("value_cents cannot be negative")
	}
	for field, value := range map[string]string{"purchase_date": input.PurchaseDate, "warranty_until": input.WarrantyUntil} {
		if value != "" {
			if _, err := time.Parse("2006-01-02", value); err != nil {
				return fmt.Errorf("%s must be YYYY-MM-DD", field)
			}
		}
	}
	input.URL = strings.TrimSpace(input.URL)
	input.Notes = strings.TrimSpace(input.Notes)
	input.Tags = normalizeTags(input.Tags)
	return nil
}

func itemFromInput(input itemInput) Item {
	return Item{
		Source: input.Source, SourceKey: input.SourceKey, Name: input.Name, Category: input.Category,
		Location: input.Location, Description: input.Description, Manufacturer: input.Manufacturer, Model: input.Model,
		Serial: input.Serial, PurchaseDate: input.PurchaseDate, WarrantyUntil: input.WarrantyUntil,
		ValueCents: input.ValueCents, Currency: input.Currency, Quantity: input.Quantity, URL: input.URL,
		Notes: input.Notes, Tags: normalizeTags(input.Tags), Archived: input.Archived,
	}
}

func writeItemsCSV(w io.Writer, items []Item) error {
	writer := csv.NewWriter(w)
	if err := writer.Write(csvFields); err != nil {
		return err
	}
	for _, item := range items {
		row := []string{
			item.Source, item.SourceKey, item.Name, item.Category, item.Location, item.Description,
			item.Manufacturer, item.Model, item.Serial, item.PurchaseDate, item.WarrantyUntil,
			strconv.FormatInt(item.ValueCents, 10), item.Currency, strconv.Itoa(item.Quantity), item.URL,
			item.Notes, strings.Join(item.Tags, ";"), strconv.FormatBool(item.Archived),
		}
		if err := writer.Write(row); err != nil {
			return err
		}
	}
	writer.Flush()
	return writer.Error()
}

func itemsFromCSV(r io.Reader) ([]itemInput, []string, error) {
	reader := csv.NewReader(r)
	reader.TrimLeadingSpace = true
	header, err := reader.Read()
	if err != nil {
		return nil, nil, fmt.Errorf("read csv header: %w", err)
	}
	columns := map[string]int{}
	for i, name := range header {
		columns[strings.ToLower(strings.TrimSpace(name))] = i
	}
	if _, ok := columns["name"]; !ok {
		return nil, nil, fmt.Errorf("csv requires a name column")
	}
	get := func(row []string, name string) string {
		i, ok := columns[name]
		if !ok || i >= len(row) {
			return ""
		}
		return row[i]
	}
	items := []itemInput{}
	warnings := []string{}
	line := 1
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		line++
		if err != nil {
			warnings = append(warnings, fmt.Sprintf("line %d: %v", line, err))
			continue
		}
		valueCents, _ := strconv.ParseInt(strings.TrimSpace(get(row, "value_cents")), 10, 64)
		quantity, _ := strconv.Atoi(strings.TrimSpace(get(row, "quantity")))
		archived, _ := strconv.ParseBool(strings.TrimSpace(get(row, "archived")))
		input := itemInput{
			Source: get(row, "source"), SourceKey: get(row, "source_key"), Name: get(row, "name"),
			Category: get(row, "category"), Location: get(row, "location"), Description: get(row, "description"),
			Manufacturer: get(row, "manufacturer"), Model: get(row, "model"), Serial: get(row, "serial"),
			PurchaseDate: get(row, "purchase_date"), WarrantyUntil: get(row, "warranty_until"),
			ValueCents: valueCents, Currency: get(row, "currency"), Quantity: quantity, URL: get(row, "url"),
			Notes: get(row, "notes"), Tags: strings.Split(get(row, "tags"), ";"), Archived: archived,
		}
		if err := validateItem(&input); err != nil {
			warnings = append(warnings, fmt.Sprintf("line %d: %v", line, err))
			continue
		}
		items = append(items, input)
	}
	return items, warnings, nil
}

type fleetInventoryFile struct {
	Hosts map[string]fleetHost `toml:"hosts"`
}

type fleetHost struct {
	Hostname     string   `toml:"hostname"`
	Status       string   `toml:"status"`
	StatusDetail string   `toml:"status_detail"`
	Kind         string   `toml:"kind"`
	Arch         string   `toml:"arch"`
	Role         string   `toml:"role"`
	Category     string   `toml:"category"`
	Users        []string `toml:"users"`
	Notes        []string `toml:"notes"`
	Hardware     struct {
		Model         string `toml:"model"`
		CPU           string `toml:"cpu"`
		GPU           string `toml:"gpu"`
		RAM           string `toml:"ram"`
		Display       string `toml:"display"`
		Battery       string `toml:"battery"`
		StorageType   string `toml:"storage_type"`
		StorageLayout string `toml:"storage_layout"`
	} `toml:"hardware"`
	Network struct {
		LANIP             string `toml:"lan_ip"`
		Tailscale         bool   `toml:"tailscale"`
		TailscaleHostname string `toml:"tailscale_hostname"`
		SSHAlias          string `toml:"ssh_alias"`
	} `toml:"network"`
	Software struct {
		ModuleChain  string   `toml:"module_chain"`
		KeyServices  []string `toml:"key_services"`
		Traits       []string `toml:"traits"`
		Impermanence bool     `toml:"impermanence"`
	} `toml:"software"`
	Persona struct {
		Title string `toml:"title"`
	} `toml:"persona"`
}

func itemsFromFleetTOML(raw []byte) ([]itemInput, error) {
	var fleet fleetInventoryFile
	if err := toml.Unmarshal(raw, &fleet); err != nil {
		return nil, err
	}
	if len(fleet.Hosts) == 0 {
		return nil, fmt.Errorf("inventory.toml contains no hosts")
	}
	keys := make([]string, 0, len(fleet.Hosts))
	for key := range fleet.Hosts {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	items := make([]itemInput, 0, len(keys))
	for _, key := range keys {
		host := fleet.Hosts[key]
		name := host.Hostname
		if name == "" {
			name = key
		}
		locationParts := []string{}
		if host.Network.TailscaleHostname != "" {
			locationParts = append(locationParts, "tailnet:"+host.Network.TailscaleHostname)
		}
		if host.Network.LANIP != "" {
			locationParts = append(locationParts, "lan:"+host.Network.LANIP)
		}
		location := strings.Join(locationParts, " / ")
		if location == "" {
			location = "fleet"
		}
		hardware := []string{}
		for _, value := range []string{host.Hardware.CPU, host.Hardware.GPU, host.Hardware.RAM, host.Hardware.StorageType, host.Hardware.Display, host.Hardware.Battery} {
			if value != "" {
				hardware = append(hardware, value)
			}
		}
		notes := []string{}
		if host.StatusDetail != "" {
			notes = append(notes, host.StatusDetail)
		}
		if len(hardware) > 0 {
			notes = append(notes, "Hardware: "+strings.Join(hardware, "; "))
		}
		if host.Hardware.StorageLayout != "" {
			notes = append(notes, "Storage layout: "+host.Hardware.StorageLayout)
		}
		if len(host.Software.KeyServices) > 0 {
			notes = append(notes, "Services: "+strings.Join(host.Software.KeyServices, "; "))
		}
		if len(host.Notes) > 0 {
			notes = append(notes, host.Notes...)
		}
		tags := append([]string{"fleet", host.Status, host.Kind, host.Arch}, host.Software.Traits...)
		manufacturer := ""
		model := host.Hardware.Model
		fields := strings.Fields(model)
		if len(fields) > 1 {
			manufacturer = fields[0]
		}
		input := itemInput{
			Source: "inventory.toml", SourceKey: "host/" + key, Name: name,
			Category: firstNonBlank(host.Category, "fleet-host"), Location: location,
			Description: firstNonBlank(host.Role, host.Persona.Title), Manufacturer: manufacturer, Model: model,
			Currency: "EUR", Quantity: 1, Notes: strings.Join(notes, "\n\n"), Tags: tags,
		}
		if err := validateItem(&input); err != nil {
			return nil, fmt.Errorf("host %s: %w", key, err)
		}
		items = append(items, input)
	}
	return items, nil
}

func firstNonBlank(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}
