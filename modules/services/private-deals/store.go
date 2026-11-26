package main

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"math"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

type runRecord struct {
	ID           int64     `json:"id"`
	Source       string    `json:"source"`
	StartedAt    time.Time `json:"started_at"`
	FinishedAt   time.Time `json:"finished_at,omitempty"`
	Status       string    `json:"status"`
	TotalFetched int       `json:"total_fetched"`
	Inserted     int       `json:"inserted"`
	Updated      int       `json:"updated"`
	Error        string    `json:"error,omitempty"`
}

type sourceState struct {
	Name         string     `json:"name"`
	LastStarted  *time.Time `json:"last_started,omitempty"`
	LastFinished *time.Time `json:"last_finished,omitempty"`
	LastStatus   string     `json:"last_status,omitempty"`
	LastError    string     `json:"last_error,omitempty"`
	TotalFetched int        `json:"total_fetched"`
	Inserted     int        `json:"inserted"`
	Updated      int        `json:"updated"`
	Runs         int        `json:"runs"`
}

func OpenStore(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path+"?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	store := &Store{db: db}
	if err := store.migrate(); err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) migrate() error {
	statements := []string{
		`PRAGMA journal_mode=WAL`,
		`CREATE TABLE IF NOT EXISTS products (
			id INTEGER PRIMARY KEY,
			fingerprint TEXT NOT NULL UNIQUE,
			canonical_url TEXT NOT NULL DEFAULT '',
			url TEXT NOT NULL DEFAULT '',
			source TEXT NOT NULL,
			merchant TEXT NOT NULL DEFAULT '',
			brand TEXT NOT NULL DEFAULT '',
			name TEXT NOT NULL,
			category TEXT NOT NULL DEFAULT '',
			image_url TEXT NOT NULL DEFAULT '',
			currency TEXT NOT NULL DEFAULT 'EUR',
			list_price REAL,
			current_price REAL,
			target_price REAL,
			discount_pct REAL NOT NULL DEFAULT 0,
			notes TEXT NOT NULL DEFAULT '',
			tags TEXT NOT NULL DEFAULT '[]',
			active INTEGER NOT NULL DEFAULT 1,
			first_seen TEXT NOT NULL,
			last_seen TEXT NOT NULL,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS deals (
			id INTEGER PRIMARY KEY,
			product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
			fingerprint TEXT NOT NULL UNIQUE,
			canonical_url TEXT NOT NULL DEFAULT '',
			url TEXT NOT NULL DEFAULT '',
			source TEXT NOT NULL,
			merchant TEXT NOT NULL DEFAULT '',
			title TEXT NOT NULL,
			description TEXT NOT NULL DEFAULT '',
			category TEXT NOT NULL DEFAULT '',
			currency TEXT NOT NULL DEFAULT 'EUR',
			price REAL,
			list_price REAL,
			discount_pct REAL NOT NULL DEFAULT 0,
			coupon_code TEXT NOT NULL DEFAULT '',
			expires_at TEXT NOT NULL DEFAULT '',
			score REAL NOT NULL DEFAULT 0,
			tags TEXT NOT NULL DEFAULT '[]',
			active INTEGER NOT NULL DEFAULT 1,
			first_seen TEXT NOT NULL,
			last_seen TEXT NOT NULL,
			seen_count INTEGER NOT NULL DEFAULT 1,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS price_history (
			id INTEGER PRIMARY KEY,
			product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
			deal_id INTEGER REFERENCES deals(id) ON DELETE CASCADE,
			price REAL,
			list_price REAL,
			discount_pct REAL NOT NULL DEFAULT 0,
			currency TEXT NOT NULL DEFAULT 'EUR',
			source TEXT NOT NULL,
			note TEXT NOT NULL DEFAULT '',
			captured_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS watchlists (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL UNIQUE,
			description TEXT NOT NULL DEFAULT '',
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS watchlist_items (
			watchlist_id INTEGER NOT NULL REFERENCES watchlists(id) ON DELETE CASCADE,
			product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
			position INTEGER NOT NULL DEFAULT 0,
			notes TEXT NOT NULL DEFAULT '',
			added_at TEXT NOT NULL,
			PRIMARY KEY (watchlist_id, product_id)
		)`,
		`CREATE TABLE IF NOT EXISTS deal_alerts (
			id INTEGER PRIMARY KEY,
			fingerprint TEXT NOT NULL UNIQUE,
			deal_id INTEGER NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
			product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
			watchlist_id INTEGER NOT NULL REFERENCES watchlists(id) ON DELETE CASCADE,
			reason TEXT NOT NULL,
			price REAL NOT NULL,
			currency TEXT NOT NULL DEFAULT 'EUR',
			title TEXT NOT NULL,
			message TEXT NOT NULL,
			status TEXT NOT NULL DEFAULT 'pending',
			attempts INTEGER NOT NULL DEFAULT 0,
			notify_error TEXT NOT NULL DEFAULT '',
			first_seen TEXT NOT NULL,
			last_seen TEXT NOT NULL,
			notified_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS ingest_runs (
			id INTEGER PRIMARY KEY,
			source TEXT NOT NULL,
			started_at TEXT NOT NULL,
			finished_at TEXT,
			status TEXT NOT NULL DEFAULT 'running',
			total_fetched INTEGER NOT NULL DEFAULT 0,
			inserted INTEGER NOT NULL DEFAULT 0,
			updated INTEGER NOT NULL DEFAULT 0,
			error TEXT NOT NULL DEFAULT ''
		)`,
		`CREATE TABLE IF NOT EXISTS source_state (
			name TEXT PRIMARY KEY,
			last_started TEXT,
			last_finished TEXT,
			last_status TEXT NOT NULL DEFAULT '',
			last_error TEXT NOT NULL DEFAULT '',
			total_fetched INTEGER NOT NULL DEFAULT 0,
			inserted INTEGER NOT NULL DEFAULT 0,
			updated INTEGER NOT NULL DEFAULT 0,
			runs INTEGER NOT NULL DEFAULT 0
		)`,
		`CREATE VIRTUAL TABLE IF NOT EXISTS deals_fts USING fts5(title, merchant, description, category, tags, tokenize='unicode61')`,
		`CREATE VIRTUAL TABLE IF NOT EXISTS products_fts USING fts5(name, merchant, brand, notes, category, tags, tokenize='unicode61')`,
		`CREATE INDEX IF NOT EXISTS idx_deals_source ON deals(source)`,
		`CREATE INDEX IF NOT EXISTS idx_deals_merchant ON deals(merchant)`,
		`CREATE INDEX IF NOT EXISTS idx_deals_active_discount ON deals(active, discount_pct DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_deals_product ON deals(product_id)`,
		`CREATE INDEX IF NOT EXISTS idx_products_merchant ON products(merchant)`,
		`CREATE INDEX IF NOT EXISTS idx_history_product ON price_history(product_id, captured_at DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_history_deal ON price_history(deal_id, captured_at DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_alerts_status ON deal_alerts(status,last_seen DESC)`,
		`CREATE INDEX IF NOT EXISTS idx_alerts_deal ON deal_alerts(deal_id)`,
		`CREATE INDEX IF NOT EXISTS idx_runs_started ON ingest_runs(started_at DESC)`,
	}
	for _, statement := range statements {
		if _, err := s.db.Exec(statement); err != nil {
			return fmt.Errorf("migrate: %w", err)
		}
	}
	return nil
}

func nowString() string { return time.Now().UTC().Format(time.RFC3339Nano) }

func parseTime(raw string) time.Time {
	t, _ := time.Parse(time.RFC3339Nano, raw)
	return t
}

func timePtr(raw sql.NullString) *time.Time {
	if !raw.Valid || raw.String == "" {
		return nil
	}
	t := parseTime(raw.String)
	return &t
}

func nullFloat(value *float64) sql.NullFloat64 {
	if value == nil {
		return sql.NullFloat64{}
	}
	return sql.NullFloat64{Float64: *value, Valid: true}
}

func floatPtr(value sql.NullFloat64) *float64 {
	if !value.Valid {
		return nil
	}
	v := value.Float64
	return &v
}

func nullInt(value *int64) sql.NullInt64 {
	if value == nil {
		return sql.NullInt64{}
	}
	return sql.NullInt64{Int64: *value, Valid: true}
}

func intPtr(value sql.NullInt64) *int64 {
	if !value.Valid {
		return nil
	}
	v := value.Int64
	return &v
}

func ftsQuery(q string) string {
	tokens := regexp.MustCompile(`[\p{L}\p{N}]+`).FindAllString(strings.ToLower(q), 8)
	quoted := make([]string, 0, len(tokens))
	for _, token := range tokens {
		quoted = append(quoted, strconv.Quote(token))
	}
	return strings.Join(quoted, " AND ")
}

func (s *Store) upsertFTS(table string, id int64, values ...string) error {
	if _, err := s.db.Exec(`DELETE FROM `+table+` WHERE rowid=?`, id); err != nil {
		return err
	}
	columns := map[string]string{
		"deals_fts":    "title, merchant, description, category, tags",
		"products_fts": "name, merchant, brand, notes, category, tags",
	}[table]
	if columns == "" {
		return errors.New("unknown fts table")
	}
	placeholders := strings.TrimRight(strings.Repeat("?,", len(values)+1), ",")
	args := make([]any, 0, len(values)+1)
	args = append(args, id)
	for _, value := range values {
		args = append(args, value)
	}
	_, err := s.db.Exec(`INSERT INTO `+table+`(rowid,`+columns+`) VALUES (`+placeholders+`)`, args...)
	return err
}

func (s *Store) productIDForURL(ctx context.Context, canonical string) (*int64, error) {
	if canonical == "" {
		return nil, nil
	}
	var id int64
	err := s.db.QueryRowContext(ctx, `SELECT id FROM products WHERE canonical_url=?`, canonical).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &id, nil
}

func (s *Store) UpsertDeal(ctx context.Context, input dealInput) (int64, bool, error) {
	deal := newDeal(input)
	if !validDeal(deal) {
		return 0, false, errors.New("deal needs a title and source")
	}
	if deal.ProductID == nil {
		productID, err := s.productIDForURL(ctx, deal.CanonicalURL)
		if err != nil {
			return 0, false, err
		}
		deal.ProductID = productID
	}
	now := nowString()
	var id int64
	var oldPrice, oldList sql.NullFloat64
	var seen int
	err := s.db.QueryRowContext(ctx, `SELECT id, price, list_price, seen_count FROM deals WHERE fingerprint=?`, deal.Fingerprint).Scan(&id, &oldPrice, &oldList, &seen)
	created := false
	if errors.Is(err, sql.ErrNoRows) {
		res, insertErr := s.db.ExecContext(ctx, `INSERT INTO deals (
			product_id, fingerprint, canonical_url, url, source, merchant, title, description, category, currency,
			price, list_price, discount_pct, coupon_code, expires_at, score, tags, active, first_seen, last_seen, seen_count, created_at, updated_at
		) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
			nullInt(deal.ProductID), deal.Fingerprint, deal.CanonicalURL, deal.URL, deal.Source, deal.Merchant, deal.Title, deal.Description, deal.Category, deal.Currency,
			nullFloat(deal.Price), nullFloat(deal.ListPrice), deal.DiscountPct, deal.CouponCode, deal.ExpiresAt, deal.Score, tagsJSON(deal.Tags), 1, now, now, 1, now, now)
		if insertErr != nil {
			return 0, false, insertErr
		}
		id, _ = res.LastInsertId()
		created = true
	} else if err != nil {
		return 0, false, err
	} else {
		if deal.ProductID == nil {
			var existingProduct sql.NullInt64
			if scanErr := s.db.QueryRowContext(ctx, `SELECT product_id FROM deals WHERE id=?`, id).Scan(&existingProduct); scanErr == nil {
				deal.ProductID = intPtr(existingProduct)
			}
		}
		_, err = s.db.ExecContext(ctx, `UPDATE deals SET product_id=?, canonical_url=?, url=?, source=?, merchant=?, title=?, description=?, category=?, currency=?,
			price=?, list_price=?, discount_pct=?, coupon_code=?, expires_at=?, score=?, tags=?, active=1, last_seen=?, seen_count=seen_count+1, updated_at=? WHERE id=?`,
			nullInt(deal.ProductID), deal.CanonicalURL, deal.URL, deal.Source, deal.Merchant, deal.Title, deal.Description, deal.Category, deal.Currency,
			nullFloat(deal.Price), nullFloat(deal.ListPrice), deal.DiscountPct, deal.CouponCode, deal.ExpiresAt, deal.Score, tagsJSON(deal.Tags), now, now, id)
		if err != nil {
			return 0, false, err
		}
	}
	if err := s.upsertFTS("deals_fts", id, deal.Title, deal.Merchant, deal.Description, deal.Category, strings.Join(deal.Tags, " ")); err != nil {
		return 0, false, err
	}
	if created || !sameMoney(oldPrice, nullFloat(deal.Price)) || !sameMoney(oldList, nullFloat(deal.ListPrice)) {
		if err := s.RecordPrice(ctx, intPtr(nullInt(deal.ProductID)), &id, deal.Price, deal.ListPrice, deal.DiscountPct, deal.Currency, deal.Source, "deal upsert"); err != nil {
			return 0, false, err
		}
		if deal.ProductID != nil && deal.Price != nil {
			_, _ = s.db.ExecContext(ctx, `UPDATE products SET current_price=?, list_price=COALESCE(?,list_price), discount_pct=?, last_seen=?, updated_at=? WHERE id=?`,
				nullFloat(deal.Price), nullFloat(deal.ListPrice), deal.DiscountPct, now, now, *deal.ProductID)
		}
	}
	return id, created, nil
}

func sameMoney(a, b sql.NullFloat64) bool {
	if a.Valid != b.Valid {
		return false
	}
	if !a.Valid {
		return true
	}
	diff := a.Float64 - b.Float64
	return diff < 0.005 && diff > -0.005
}

func (s *Store) UpsertProduct(ctx context.Context, input productInput) (int64, bool, error) {
	product := newProduct(input)
	if !validProduct(product) {
		return 0, false, errors.New("product needs a name and source")
	}
	now := nowString()
	var id int64
	err := s.db.QueryRowContext(ctx, `SELECT id FROM products WHERE fingerprint=?`, product.Fingerprint).Scan(&id)
	created := false
	if errors.Is(err, sql.ErrNoRows) {
		res, insertErr := s.db.ExecContext(ctx, `INSERT INTO products (
			fingerprint, canonical_url, url, source, merchant, brand, name, category, image_url, currency,
			list_price, current_price, target_price, discount_pct, notes, tags, active, first_seen, last_seen, created_at, updated_at
		) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
			product.Fingerprint, product.CanonicalURL, product.URL, product.Source, product.Merchant, product.Brand, product.Name, product.Category, product.ImageURL, product.Currency,
			nullFloat(product.ListPrice), nullFloat(product.CurrentPrice), nullFloat(product.TargetPrice), product.DiscountPct, product.Notes, tagsJSON(product.Tags), 1, now, now, now, now)
		if insertErr != nil {
			return 0, false, insertErr
		}
		id, _ = res.LastInsertId()
		created = true
	} else if err != nil {
		return 0, false, err
	} else {
		_, err = s.db.ExecContext(ctx, `UPDATE products SET canonical_url=?, url=?, source=?, merchant=?, brand=?, name=?, category=?, image_url=?, currency=?,
			list_price=?, current_price=?, target_price=?, discount_pct=?, notes=?, tags=?, active=1, last_seen=?, updated_at=? WHERE id=?`,
			product.CanonicalURL, product.URL, product.Source, product.Merchant, product.Brand, product.Name, product.Category, product.ImageURL, product.Currency,
			nullFloat(product.ListPrice), nullFloat(product.CurrentPrice), nullFloat(product.TargetPrice), product.DiscountPct, product.Notes, tagsJSON(product.Tags), now, now, id)
		if err != nil {
			return 0, false, err
		}
	}
	if err := s.upsertFTS("products_fts", id, product.Name, product.Merchant, product.Brand, product.Notes, product.Category, strings.Join(product.Tags, " ")); err != nil {
		return 0, false, err
	}
	if product.CurrentPrice != nil {
		if err := s.RecordPrice(ctx, &id, nil, product.CurrentPrice, product.ListPrice, product.DiscountPct, product.Currency, product.Source, "product upsert"); err != nil {
			return 0, false, err
		}
	}
	return id, created, nil
}

func (s *Store) RecordPrice(ctx context.Context, productID, dealID *int64, price, list *float64, discount float64, currency, source, note string) error {
	if price == nil && list == nil {
		return nil
	}
	if currency == "" {
		currency = "EUR"
	}
	if source == "" {
		source = "manual"
	}
	var latestPrice, latestList sql.NullFloat64
	var captured string
	query := `SELECT price,list_price,captured_at FROM price_history WHERE `
	args := []any{}
	if productID != nil {
		query += `product_id=?`
		args = append(args, *productID)
	} else if dealID != nil {
		query += `deal_id=?`
		args = append(args, *dealID)
	} else {
		return errors.New("price point needs a product or deal")
	}
	query += ` ORDER BY captured_at DESC LIMIT 1`
	err := s.db.QueryRowContext(ctx, query, args...).Scan(&latestPrice, &latestList, &captured)
	if err == nil && sameMoney(latestPrice, nullFloat(price)) && sameMoney(latestList, nullFloat(list)) {
		if t := parseTime(captured); time.Since(t) < 6*time.Hour {
			return nil
		}
	}
	_, err = s.db.ExecContext(ctx, `INSERT INTO price_history (product_id,deal_id,price,list_price,discount_pct,currency,source,note,captured_at) VALUES (?,?,?,?,?,?,?,?,?)`,
		nullInt(productID), nullInt(dealID), nullFloat(price), nullFloat(list), discount, normalizeCurrency(currency), source, note, nowString())
	return err
}

type dealQueryOptions struct {
	Q           string
	Source      string
	Merchant    string
	Category    string
	Active      bool
	MinDiscount float64
	MaxPrice    float64
	WatchlistID int64
	Limit       int
	Offset      int
}

type dealPage struct {
	Items  []Deal `json:"items"`
	Total  int    `json:"total"`
	Limit  int    `json:"limit"`
	Offset int    `json:"offset"`
}

func dealWhere(opts dealQueryOptions) (string, []any) {
	where := []string{"1=1"}
	args := []any{}
	if opts.Active {
		where = append(where, "d.active=1")
	}
	if opts.Source != "" {
		where = append(where, "d.source=?")
		args = append(args, opts.Source)
	}
	if opts.Merchant != "" {
		where = append(where, "LOWER(d.merchant) LIKE ?")
		args = append(args, "%"+strings.ToLower(opts.Merchant)+"%")
	}
	if opts.Category != "" {
		where = append(where, "d.category=?")
		args = append(args, strings.ToLower(opts.Category))
	}
	if opts.MinDiscount > 0 {
		where = append(where, "d.discount_pct>=?")
		args = append(args, opts.MinDiscount)
	}
	if opts.MaxPrice > 0 {
		where = append(where, "d.price<=?")
		args = append(args, opts.MaxPrice)
	}
	if opts.WatchlistID > 0 {
		where = append(where, "d.product_id IN (SELECT product_id FROM watchlist_items WHERE watchlist_id=?)")
		args = append(args, opts.WatchlistID)
	}
	if fts := ftsQuery(opts.Q); fts != "" {
		where = append(where, "d.id IN (SELECT rowid FROM deals_fts WHERE deals_fts MATCH ?)")
		args = append(args, fts)
	}
	return strings.Join(where, " AND "), args
}

func scanDeal(row interface{ Scan(...any) error }) (Deal, error) {
	var d Deal
	var productID sql.NullInt64
	var price, list sql.NullFloat64
	var tags, firstSeen, lastSeen, createdAt, updatedAt string
	var active int
	err := row.Scan(&d.ID, &productID, &d.Fingerprint, &d.CanonicalURL, &d.URL, &d.Source, &d.Merchant, &d.Title, &d.Description, &d.Category, &d.Currency,
		&price, &list, &d.DiscountPct, &d.CouponCode, &d.ExpiresAt, &d.Score, &tags, &active, &firstSeen, &lastSeen, &d.SeenCount, &createdAt, &updatedAt)
	if err != nil {
		return d, err
	}
	d.Active = active == 1
	d.ProductID = intPtr(productID)
	d.Price = floatPtr(price)
	d.ListPrice = floatPtr(list)
	d.Tags = parseTagsJSON(tags)
	d.FirstSeen = parseTime(firstSeen)
	d.LastSeen = parseTime(lastSeen)
	d.CreatedAt = parseTime(createdAt)
	d.UpdatedAt = parseTime(updatedAt)
	return d, nil
}

const dealColumns = `id,product_id,fingerprint,canonical_url,url,source,merchant,title,description,category,currency,price,list_price,discount_pct,coupon_code,expires_at,score,tags,active,first_seen,last_seen,seen_count,created_at,updated_at`

func (s *Store) QueryDeals(ctx context.Context, opts dealQueryOptions) (dealPage, error) {
	if opts.Limit <= 0 || opts.Limit > 200 {
		opts.Limit = 50
	}
	where, args := dealWhere(opts)
	var total int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM deals d WHERE `+where, args...).Scan(&total); err != nil {
		return dealPage{}, err
	}
	query := `SELECT ` + dealColumns + ` FROM deals d WHERE ` + where + ` ORDER BY d.score DESC, d.discount_pct DESC, d.last_seen DESC LIMIT ? OFFSET ?`
	rows, err := s.db.QueryContext(ctx, query, append(args, opts.Limit, opts.Offset)...)
	if err != nil {
		return dealPage{}, err
	}
	defer rows.Close()
	items := []Deal{}
	for rows.Next() {
		deal, err := scanDeal(rows)
		if err != nil {
			return dealPage{}, err
		}
		items = append(items, deal)
	}
	if err := rows.Err(); err != nil {
		return dealPage{}, err
	}
	if err := rows.Close(); err != nil {
		return dealPage{}, err
	}
	if opts.Q != "" {
		match := ftsQuery(opts.Q)
		for index := range items {
			_ = s.db.QueryRowContext(ctx, `SELECT highlight(deals_fts,0,'<mark>','</mark>') FROM deals_fts WHERE rowid=? AND deals_fts MATCH ?`, items[index].ID, match).Scan(&items[index].Snippet)
		}
	}
	return dealPage{Items: items, Total: total, Limit: opts.Limit, Offset: opts.Offset}, nil
}

func (s *Store) GetDeal(ctx context.Context, id int64) (Deal, []PricePoint, error) {
	deal, err := scanDeal(s.db.QueryRowContext(ctx, `SELECT `+dealColumns+` FROM deals WHERE id=?`, id))
	if err != nil {
		return deal, nil, err
	}
	history, err := s.PriceHistory(ctx, deal.ProductID, &id, 100)
	return deal, history, err
}

type productQueryOptions struct {
	Q        string
	Source   string
	Merchant string
	Category string
	Active   bool
	Limit    int
	Offset   int
}

type productPage struct {
	Items  []Product `json:"items"`
	Total  int       `json:"total"`
	Limit  int       `json:"limit"`
	Offset int       `json:"offset"`
}

func scanProduct(row interface{ Scan(...any) error }) (Product, error) {
	var p Product
	var list, current, target sql.NullFloat64
	var tags, firstSeen, lastSeen, createdAt, updatedAt string
	var active int
	err := row.Scan(&p.ID, &p.Fingerprint, &p.CanonicalURL, &p.URL, &p.Source, &p.Merchant, &p.Brand, &p.Name, &p.Category, &p.ImageURL, &p.Currency,
		&list, &current, &target, &p.DiscountPct, &p.Notes, &tags, &active, &firstSeen, &lastSeen, &createdAt, &updatedAt)
	if err != nil {
		return p, err
	}
	p.Active = active == 1
	p.ListPrice = floatPtr(list)
	p.CurrentPrice = floatPtr(current)
	p.TargetPrice = floatPtr(target)
	p.Tags = parseTagsJSON(tags)
	p.FirstSeen = parseTime(firstSeen)
	p.LastSeen = parseTime(lastSeen)
	p.CreatedAt = parseTime(createdAt)
	p.UpdatedAt = parseTime(updatedAt)
	return p, nil
}

const productColumns = `id,fingerprint,canonical_url,url,source,merchant,brand,name,category,image_url,currency,list_price,current_price,target_price,discount_pct,notes,tags,active,first_seen,last_seen,created_at,updated_at`

func prefixedProductColumns() string {
	parts := strings.Split(productColumns, ",")
	for index, part := range parts {
		parts[index] = "p." + part
	}
	return strings.Join(parts, ",")
}

func (s *Store) QueryProducts(ctx context.Context, opts productQueryOptions) (productPage, error) {
	if opts.Limit <= 0 || opts.Limit > 200 {
		opts.Limit = 50
	}
	where := []string{"1=1"}
	args := []any{}
	if opts.Active {
		where = append(where, "active=1")
	}
	if opts.Source != "" {
		where = append(where, "source=?")
		args = append(args, opts.Source)
	}
	if opts.Merchant != "" {
		where = append(where, "LOWER(merchant) LIKE ?")
		args = append(args, "%"+strings.ToLower(opts.Merchant)+"%")
	}
	if opts.Category != "" {
		where = append(where, "category=?")
		args = append(args, strings.ToLower(opts.Category))
	}
	if fts := ftsQuery(opts.Q); fts != "" {
		where = append(where, "id IN (SELECT rowid FROM products_fts WHERE products_fts MATCH ?)")
		args = append(args, fts)
	}
	clause := strings.Join(where, " AND ")
	var total int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM products WHERE `+clause, args...).Scan(&total); err != nil {
		return productPage{}, err
	}
	rows, err := s.db.QueryContext(ctx, `SELECT `+productColumns+` FROM products WHERE `+clause+` ORDER BY discount_pct DESC,last_seen DESC LIMIT ? OFFSET ?`, append(args, opts.Limit, opts.Offset)...)
	if err != nil {
		return productPage{}, err
	}
	defer rows.Close()
	items := []Product{}
	for rows.Next() {
		product, err := scanProduct(rows)
		if err != nil {
			return productPage{}, err
		}
		items = append(items, product)
	}
	return productPage{Items: items, Total: total, Limit: opts.Limit, Offset: opts.Offset}, rows.Err()
}

func (s *Store) GetProduct(ctx context.Context, id int64) (Product, []PricePoint, []Deal, error) {
	product, err := scanProduct(s.db.QueryRowContext(ctx, `SELECT `+productColumns+` FROM products WHERE id=?`, id))
	if err != nil {
		return product, nil, nil, err
	}
	history, err := s.PriceHistory(ctx, &id, nil, 200)
	if err != nil {
		return product, nil, nil, err
	}
	rows, err := s.db.QueryContext(ctx, `SELECT `+dealColumns+` FROM deals WHERE product_id=? ORDER BY last_seen DESC LIMIT 20`, id)
	if err != nil {
		return product, nil, nil, err
	}
	defer rows.Close()
	deals := []Deal{}
	for rows.Next() {
		deal, scanErr := scanDeal(rows)
		if scanErr != nil {
			return product, nil, nil, scanErr
		}
		deals = append(deals, deal)
	}
	return product, history, deals, rows.Err()
}

func (s *Store) PriceHistory(ctx context.Context, productID, dealID *int64, limit int) ([]PricePoint, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	where := "1=1"
	args := []any{}
	if productID != nil && dealID != nil {
		where += " AND (product_id=? OR deal_id=?)"
		args = append(args, *productID, *dealID)
	} else if productID != nil {
		where += " AND product_id=?"
		args = append(args, *productID)
	} else if dealID != nil {
		where += " AND deal_id=?"
		args = append(args, *dealID)
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id,product_id,deal_id,price,list_price,discount_pct,currency,source,note,captured_at FROM price_history WHERE `+where+` ORDER BY captured_at DESC LIMIT ?`, append(args, limit)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	points := []PricePoint{}
	for rows.Next() {
		var point PricePoint
		var product, deal sql.NullInt64
		var price, list sql.NullFloat64
		var captured string
		if err := rows.Scan(&point.ID, &product, &deal, &price, &list, &point.DiscountPct, &point.Currency, &point.Source, &point.Note, &captured); err != nil {
			return nil, err
		}
		point.ProductID = intPtr(product)
		point.DealID = intPtr(deal)
		point.Price = floatPtr(price)
		point.ListPrice = floatPtr(list)
		point.CapturedAt = parseTime(captured)
		points = append(points, point)
	}
	return points, rows.Err()
}

func (s *Store) CreateWatchlist(ctx context.Context, name, description string) (int64, error) {
	name = cleanText(name)
	if len(name) < 2 {
		return 0, errors.New("watchlist name must be at least two characters")
	}
	now := nowString()
	res, err := s.db.ExecContext(ctx, `INSERT INTO watchlists (name,description,created_at,updated_at) VALUES (?,?,?,?)`, name, strings.TrimSpace(description), now, now)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (s *Store) Watchlists(ctx context.Context) ([]Watchlist, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT w.id,w.name,w.description,w.created_at,w.updated_at,count(i.product_id) FROM watchlists w LEFT JOIN watchlist_items i ON i.watchlist_id=w.id GROUP BY w.id ORDER BY w.name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	lists := []Watchlist{}
	for rows.Next() {
		var list Watchlist
		var created, updated string
		if err := rows.Scan(&list.ID, &list.Name, &list.Description, &created, &updated, &list.ItemCount); err != nil {
			return nil, err
		}
		list.CreatedAt = parseTime(created)
		list.UpdatedAt = parseTime(updated)
		lists = append(lists, list)
	}
	return lists, rows.Err()
}

func (s *Store) AddWatchlistItem(ctx context.Context, watchlistID, productID int64, notes string) error {
	var exists int
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM watchlists WHERE id=?`, watchlistID).Scan(&exists); err != nil || exists == 0 {
		return errors.New("watchlist not found")
	}
	if err := s.db.QueryRowContext(ctx, `SELECT count(*) FROM products WHERE id=?`, productID).Scan(&exists); err != nil || exists == 0 {
		return errors.New("product not found")
	}
	_, err := s.db.ExecContext(ctx, `INSERT INTO watchlist_items (watchlist_id,product_id,position,notes,added_at) VALUES (?,?,?,?,?)
		ON CONFLICT(watchlist_id,product_id) DO UPDATE SET notes=excluded.notes`, watchlistID, productID, 0, strings.TrimSpace(notes), nowString())
	if err == nil {
		_, _ = s.db.ExecContext(ctx, `UPDATE watchlists SET updated_at=? WHERE id=?`, nowString(), watchlistID)
	}
	return err
}

func (s *Store) RemoveWatchlistItem(ctx context.Context, watchlistID, productID int64) error {
	res, err := s.db.ExecContext(ctx, `DELETE FROM watchlist_items WHERE watchlist_id=? AND product_id=?`, watchlistID, productID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return errors.New("watchlist item not found")
	}
	_, _ = s.db.ExecContext(ctx, `UPDATE watchlists SET updated_at=? WHERE id=?`, nowString(), watchlistID)
	return nil
}

func (s *Store) WatchlistItems(ctx context.Context, watchlistID int64) ([]WatchlistItem, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT i.watchlist_id,i.product_id,i.position,i.notes,i.added_at,`+prefixedProductColumns()+` FROM watchlist_items i JOIN products p ON p.id=i.product_id WHERE i.watchlist_id=? ORDER BY i.position,i.added_at DESC`, watchlistID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []WatchlistItem{}
	for rows.Next() {
		var item WatchlistItem
		var product Product
		var list, current, target sql.NullFloat64
		var tags, firstSeen, lastSeen, createdAt, updatedAt, added string
		var active int
		if err := rows.Scan(&item.WatchlistID, &item.ProductID, &item.Position, &item.Notes, &added,
			&product.ID, &product.Fingerprint, &product.CanonicalURL, &product.URL, &product.Source, &product.Merchant, &product.Brand, &product.Name, &product.Category, &product.ImageURL, &product.Currency,
			&list, &current, &target, &product.DiscountPct, &product.Notes, &tags, &active, &firstSeen, &lastSeen, &createdAt, &updatedAt); err != nil {
			return nil, err
		}
		item.AddedAt = parseTime(added)
		product.Active = active == 1
		product.ListPrice = floatPtr(list)
		product.CurrentPrice = floatPtr(current)
		product.TargetPrice = floatPtr(target)
		product.Tags = parseTagsJSON(tags)
		product.FirstSeen = parseTime(firstSeen)
		product.LastSeen = parseTime(lastSeen)
		product.CreatedAt = parseTime(createdAt)
		product.UpdatedAt = parseTime(updatedAt)
		item.Product = &product
		items = append(items, item)
	}
	return items, rows.Err()
}

func alertFingerprint(dealID int64, currency string, price float64) string {
	return fmt.Sprintf("%d:%s:%.2f", dealID, normalizeCurrency(currency), price)
}

func alertReason(price float64, current, target *float64) string {
	if target != nil && price <= *target {
		return "target-price"
	}
	if current != nil && price < *current*0.95 {
		return "price-drop"
	}
	return "watchlist-match"
}

func (s *Store) EvaluateWatchlistAlerts(ctx context.Context, limit int) (alertEvaluation, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	rows, err := s.db.QueryContext(ctx, `SELECT d.id,d.title,d.price,d.currency,p.id,p.name,p.current_price,p.target_price,min(w.id),w.name
		FROM deals d
		JOIN products p ON p.id=d.product_id
		JOIN watchlist_items i ON i.product_id=p.id
		JOIN watchlists w ON w.id=i.watchlist_id
		WHERE d.active=1 AND p.active=1 AND d.price IS NOT NULL
		GROUP BY d.id
		ORDER BY d.last_seen DESC LIMIT ?`, limit)
	if err != nil {
		return alertEvaluation{}, err
	}
	candidates := []DealAlert{}
	for rows.Next() {
		var alert DealAlert
		var current, target sql.NullFloat64
		if err := rows.Scan(&alert.DealID, &alert.Title, &alert.Price, &alert.Currency, &alert.ProductID, &alert.ProductName, &current, &target, &alert.WatchlistID, &alert.Watchlist); err != nil {
			rows.Close()
			return alertEvaluation{}, err
		}
		currentPtr, targetPtr := floatPtr(current), floatPtr(target)
		alert.Reason = alertReason(alert.Price, currentPtr, targetPtr)
		alert.Message = fmt.Sprintf("%s is %.2f %s at %s", alert.ProductName, alert.Price, alert.Currency, alert.Title)
		if alert.Reason == "target-price" && targetPtr != nil {
			alert.Message = fmt.Sprintf("%s hit target %.2f %s: %.2f %s", alert.ProductName, *targetPtr, alert.Currency, alert.Price, alert.Currency)
		}
		candidates = append(candidates, alert)
	}
	if err := rows.Close(); err != nil {
		return alertEvaluation{}, err
	}
	if err := rows.Err(); err != nil {
		return alertEvaluation{}, err
	}

	result := alertEvaluation{Alerts: []DealAlert{}}
	for _, alert := range candidates {
		fingerprint := alertFingerprint(alert.DealID, alert.Currency, alert.Price)
		now := nowString()
		res, err := s.db.ExecContext(ctx, `INSERT OR IGNORE INTO deal_alerts (fingerprint,deal_id,product_id,watchlist_id,reason,price,currency,title,message,status,first_seen,last_seen) VALUES (?,?,?,?,?,?,?,?,?,'pending',?,?)`, fingerprint, alert.DealID, alert.ProductID, alert.WatchlistID, alert.Reason, alert.Price, alert.Currency, alert.Title, alert.Message, now, now)
		if err != nil {
			return result, err
		}
		if n, _ := res.RowsAffected(); n > 0 {
			result.Created++
			alert.ID, _ = res.LastInsertId()
			alert.Status = "pending"
			alert.FirstSeen = parseTime(now)
			alert.LastSeen = parseTime(now)
		} else {
			result.Existing++
			if _, err := s.db.ExecContext(ctx, `UPDATE deal_alerts SET last_seen=?,title=?,message=?,reason=? WHERE fingerprint=?`, now, alert.Title, alert.Message, alert.Reason, fingerprint); err != nil {
				return result, err
			}
			var firstSeen, lastSeen string
			var notified sql.NullString
			err := s.db.QueryRowContext(ctx, `SELECT id,status,attempts,notify_error,first_seen,last_seen,notified_at FROM deal_alerts WHERE fingerprint=?`, fingerprint).Scan(&alert.ID, &alert.Status, &alert.Attempts, &alert.NotifyError, &firstSeen, &lastSeen, &notified)
			if err != nil {
				return result, err
			}
			alert.FirstSeen = parseTime(firstSeen)
			alert.LastSeen = parseTime(lastSeen)
			if notified.Valid {
				t := parseTime(notified.String)
				alert.NotifiedAt = &t
			}
		}
		result.Matched++
		result.Alerts = append(result.Alerts, alert)
	}
	return result, nil
}

func (s *Store) ListAlerts(ctx context.Context, limit int, status string) ([]DealAlert, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	where, args := "1=1", []any{}
	if status != "" {
		where += " AND a.status=?"
		args = append(args, status)
	}
	rows, err := s.db.QueryContext(ctx, `SELECT a.id,a.deal_id,a.product_id,a.watchlist_id,a.reason,a.price,a.currency,a.title,a.message,a.status,a.attempts,a.notify_error,a.first_seen,a.last_seen,COALESCE(a.notified_at,''),w.name,p.name
		FROM deal_alerts a JOIN watchlists w ON w.id=a.watchlist_id JOIN products p ON p.id=a.product_id
		WHERE `+where+` ORDER BY a.last_seen DESC LIMIT ?`, append(args, limit)...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	alerts := []DealAlert{}
	for rows.Next() {
		var alert DealAlert
		var firstSeen, lastSeen, notified string
		if err := rows.Scan(&alert.ID, &alert.DealID, &alert.ProductID, &alert.WatchlistID, &alert.Reason, &alert.Price, &alert.Currency, &alert.Title, &alert.Message, &alert.Status, &alert.Attempts, &alert.NotifyError, &firstSeen, &lastSeen, &notified, &alert.Watchlist, &alert.ProductName); err != nil {
			return nil, err
		}
		alert.FirstSeen = parseTime(firstSeen)
		alert.LastSeen = parseTime(lastSeen)
		if notified != "" {
			t := parseTime(notified)
			alert.NotifiedAt = &t
		}
		alerts = append(alerts, alert)
	}
	return alerts, rows.Err()
}

func (s *Store) MarkAlertNotification(ctx context.Context, id int64, sent bool, notifyError string) error {
	status := "failed"
	if sent {
		status = "sent"
	}
	notified := ""
	if sent {
		notified = nowString()
	}
	_, err := s.db.ExecContext(ctx, `UPDATE deal_alerts SET status=?,attempts=attempts+1,notify_error=?,notified_at=?,last_seen=? WHERE id=?`, status, notifyError, notified, nowString(), id)
	return err
}

func (s *Store) Stats(ctx context.Context) (map[string]any, error) {
	stats := map[string]any{}
	for key, query := range map[string]string{
		"deals":          `SELECT count(*) FROM deals WHERE active=1`,
		"products":       `SELECT count(*) FROM products WHERE active=1`,
		"watchlists":     `SELECT count(*) FROM watchlists`,
		"price_points":   `SELECT count(*) FROM price_history`,
		"merchants":      `SELECT count(DISTINCT merchant) FROM deals WHERE merchant<>''`,
		"discount_avg":   `SELECT COALESCE(round(avg(discount_pct),1),0) FROM deals WHERE active=1 AND discount_pct>0`,
		"discount_max":   `SELECT COALESCE(max(discount_pct),0) FROM deals WHERE active=1`,
		"price_drops_7d": `SELECT count(*) FROM price_history WHERE captured_at>=?`,
		"alerts":         `SELECT count(*) FROM deal_alerts`,
		"alerts_sent":    `SELECT count(*) FROM deal_alerts WHERE status='sent'`,
		"alerts_pending": `SELECT count(*) FROM deal_alerts WHERE status='pending'`,
	} {
		if key == "price_drops_7d" {
			var value int
			if err := s.db.QueryRowContext(ctx, query, time.Now().UTC().Add(-7*24*time.Hour).Format(time.RFC3339Nano)).Scan(&value); err != nil {
				return nil, err
			}
			stats[key] = value
			continue
		}
		var value float64
		if err := s.db.QueryRowContext(ctx, query).Scan(&value); err != nil {
			return nil, err
		}
		if key == "discount_avg" || key == "discount_max" {
			stats[key] = value
		} else {
			stats[key] = int(value)
		}
	}
	return stats, nil
}

func roundMoney(value float64) float64 { return math.Round(value*100) / 100 }

// Analytics is the page's other reading: not one deal at a time but the shape of
// them. Every figure is over active deals, and every ordering has a tiebreak so
// two runs over the same rows answer the same way.
func (s *Store) Analytics(ctx context.Context, opts analyticsQuery) (analyticsReport, error) {
	window := opts.Window
	if window <= 0 {
		window = 30
	}
	if window > 365 {
		window = 365
	}
	limit := opts.Limit
	if limit <= 0 {
		limit = 5
	}
	if limit > 50 {
		limit = 50
	}
	sinceText := time.Now().UTC().AddDate(0, 0, -window).Format(time.RFC3339Nano)
	report := analyticsReport{
		GeneratedAt:  time.Now().UTC(),
		WindowDays:   window,
		TopDiscounts: []analyticsDeal{},
		BiggestDrops: []analyticsMovement{},
		Merchants:    []analyticsBucket{},
		Categories:   []analyticsBucket{},
	}
	report.History = historySummary{WindowDays: window, Currency: "EUR", Daily: []historyDay{}}

	discounts, err := s.db.QueryContext(ctx, `SELECT id,title,merchant,category,price,list_price,discount_pct,currency,url,last_seen
		FROM deals WHERE active=1 AND discount_pct>0
		ORDER BY discount_pct DESC, COALESCE(price,1e18) ASC, id ASC LIMIT ?`, limit)
	if err != nil {
		return report, err
	}
	for discounts.Next() {
		var deal analyticsDeal
		var price, list sql.NullFloat64
		var seen string
		if err := discounts.Scan(&deal.ID, &deal.Title, &deal.Merchant, &deal.Category, &price, &list, &deal.DiscountPct, &deal.Currency, &deal.URL, &seen); err != nil {
			discounts.Close()
			return report, err
		}
		deal.Price = floatPtr(price)
		deal.ListPrice = floatPtr(list)
		deal.LastSeen = parseTime(seen)
		report.TopDiscounts = append(report.TopDiscounts, deal)
	}
	if err := discounts.Err(); err != nil {
		discounts.Close()
		return report, err
	}
	discounts.Close()

	buckets := func(query string) ([]analyticsBucket, error) {
		rows, err := s.db.QueryContext(ctx, query, limit)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		out := []analyticsBucket{}
		for rows.Next() {
			var bucket analyticsBucket
			var minPrice sql.NullFloat64
			if err := rows.Scan(&bucket.Name, &bucket.Deals, &bucket.AvgDiscount, &bucket.MaxDiscount, &minPrice); err != nil {
				return nil, err
			}
			bucket.MinPrice = floatPtr(minPrice)
			out = append(out, bucket)
		}
		return out, rows.Err()
	}
	if report.Merchants, err = buckets(`SELECT CASE WHEN merchant='' THEN source ELSE merchant END AS name,
		count(*), COALESCE(round(avg(discount_pct),1),0), COALESCE(max(discount_pct),0), min(price)
		FROM deals WHERE active=1 GROUP BY name
		ORDER BY count(*) DESC, avg(discount_pct) DESC, name ASC LIMIT ?`); err != nil {
		return report, err
	}
	if report.Categories, err = buckets(`SELECT CASE WHEN category='' THEN 'uncategorised' ELSE category END AS name,
		count(*), COALESCE(round(avg(discount_pct),1),0), COALESCE(max(discount_pct),0), min(price)
		FROM deals WHERE active=1 GROUP BY name
		ORDER BY count(*) DESC, avg(discount_pct) DESC, name ASC LIMIT ?`); err != nil {
		return report, err
	}

	// First and last price per product inside the window, one pass: the drop list
	// and the fell/rose counts are the same rows read two ways.
	movements, err := s.db.QueryContext(ctx, `WITH pts AS (
			SELECT product_id, price, captured_at,
				ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY captured_at ASC, id ASC) AS first_rank,
				ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY captured_at DESC, id DESC) AS last_rank,
				COUNT(*) OVER (PARTITION BY product_id) AS points
			FROM price_history
			WHERE product_id IS NOT NULL AND price IS NOT NULL AND price>0 AND captured_at>=?
		)
		SELECT f.product_id, p.name, p.merchant, p.currency, p.target_price,
			f.price, l.price, f.captured_at, l.captured_at, l.points
		FROM pts f
		JOIN pts l ON l.product_id=f.product_id AND l.last_rank=1
		JOIN products p ON p.id=f.product_id
		WHERE f.first_rank=1 AND l.points>=2
		LIMIT 2000`, sinceText)
	if err != nil {
		return report, err
	}
	for movements.Next() {
		var row struct {
			productID            int64
			name, merchant, curr string
			target               sql.NullFloat64
			first, last          float64
			firstAt, lastAt      string
			points               int
		}
		if err := movements.Scan(&row.productID, &row.name, &row.merchant, &row.curr, &row.target, &row.first, &row.last, &row.firstAt, &row.lastAt, &row.points); err != nil {
			movements.Close()
			return report, err
		}
		switch {
		case row.last < row.first:
			report.History.Fell++
		case row.last > row.first:
			report.History.Rose++
		default:
			report.History.Flat++
		}
		if row.last >= row.first || row.first <= 0 {
			continue
		}
		report.BiggestDrops = append(report.BiggestDrops, analyticsMovement{
			ProductID: row.productID, Name: row.name, Merchant: row.merchant, Currency: normalizeCurrency(row.curr),
			From: roundMoney(row.first), To: roundMoney(row.last),
			DropPct: round1((row.first - row.last) / row.first * 100), Points: row.points,
			TargetPrice: floatPtr(row.target), FirstAt: parseTime(row.firstAt), LastAt: parseTime(row.lastAt),
		})
	}
	if err := movements.Err(); err != nil {
		movements.Close()
		return report, err
	}
	movements.Close()
	sort.SliceStable(report.BiggestDrops, func(i, j int) bool {
		if report.BiggestDrops[i].DropPct != report.BiggestDrops[j].DropPct {
			return report.BiggestDrops[i].DropPct > report.BiggestDrops[j].DropPct
		}
		if !report.BiggestDrops[i].LastAt.Equal(report.BiggestDrops[j].LastAt) {
			return report.BiggestDrops[i].LastAt.After(report.BiggestDrops[j].LastAt)
		}
		return report.BiggestDrops[i].ProductID < report.BiggestDrops[j].ProductID
	})
	if len(report.BiggestDrops) > limit {
		report.BiggestDrops = report.BiggestDrops[:limit]
	}

	var points, products int
	var avgPrice, minPrice, maxPrice sql.NullFloat64
	if err := s.db.QueryRowContext(ctx, `SELECT count(*), count(DISTINCT product_id), avg(price), min(price), max(price)
		FROM price_history WHERE price IS NOT NULL AND price>0 AND captured_at>=?`, sinceText).
		Scan(&points, &products, &avgPrice, &minPrice, &maxPrice); err != nil {
		return report, err
	}
	report.History.Points = points
	report.History.Products = products
	if avgPrice.Valid {
		value := roundMoney(avgPrice.Float64)
		report.History.AvgPrice = &value
	}
	if minPrice.Valid {
		value := roundMoney(minPrice.Float64)
		report.History.MinPrice = &value
	}
	if maxPrice.Valid {
		value := roundMoney(maxPrice.Float64)
		report.History.MaxPrice = &value
	}

	daily, err := s.db.QueryContext(ctx, `SELECT substr(captured_at,1,10) AS day, count(*), avg(price), min(price)
		FROM price_history WHERE price IS NOT NULL AND price>0 AND captured_at>=?
		GROUP BY day ORDER BY day ASC`, sinceText)
	if err != nil {
		return report, err
	}
	for daily.Next() {
		var day historyDay
		var avg, min sql.NullFloat64
		if err := daily.Scan(&day.Day, &day.Points, &avg, &min); err != nil {
			daily.Close()
			return report, err
		}
		if avg.Valid {
			value := roundMoney(avg.Float64)
			day.AvgPrice = &value
		}
		if min.Valid {
			value := roundMoney(min.Float64)
			day.MinPrice = &value
		}
		report.History.Daily = append(report.History.Daily, day)
	}
	if err := daily.Err(); err != nil {
		daily.Close()
		return report, err
	}
	daily.Close()

	if currency := ""; s.db.QueryRowContext(ctx, `SELECT currency FROM price_history
		WHERE price IS NOT NULL AND price>0 AND captured_at>=?
		GROUP BY currency ORDER BY count(*) DESC, currency ASC LIMIT 1`, sinceText).Scan(&currency) == nil && currency != "" {
		report.History.Currency = normalizeCurrency(currency)
	}
	return report, nil
}

func (s *Store) BeginRun(ctx context.Context, source string) (int64, error) {
	res, err := s.db.ExecContext(ctx, `INSERT INTO ingest_runs (source,started_at,status) VALUES (?,?, 'running')`, source, nowString())
	if err != nil {
		return 0, err
	}
	id, _ := res.LastInsertId()
	_, _ = s.db.ExecContext(ctx, `INSERT INTO source_state (name,last_started,last_status,runs) VALUES (?,?, 'running',1)
		ON CONFLICT(name) DO UPDATE SET last_started=excluded.last_started,last_status='running',runs=runs+1`, source, nowString())
	return id, nil
}

func (s *Store) FinishRun(ctx context.Context, runID int64, source, status string, fetched, inserted, updated int, errText string) error {
	now := nowString()
	_, err := s.db.ExecContext(ctx, `UPDATE ingest_runs SET finished_at=?,status=?,total_fetched=?,inserted=?,updated=?,error=? WHERE id=?`, now, status, fetched, inserted, updated, errText, runID)
	if err != nil {
		return err
	}
	_, err = s.db.ExecContext(ctx, `INSERT INTO source_state (name,last_finished,last_status,last_error,total_fetched,inserted,updated,runs) VALUES (?,?,?,?,?,?,?,1)
		ON CONFLICT(name) DO UPDATE SET last_finished=excluded.last_finished,last_status=excluded.last_status,last_error=excluded.last_error,
		total_fetched=total_fetched+excluded.total_fetched,inserted=inserted+excluded.inserted,updated=updated+excluded.updated`, source, now, status, errText, fetched, inserted, updated)
	return err
}

func (s *Store) RecentRuns(ctx context.Context, limit int) ([]runRecord, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	rows, err := s.db.QueryContext(ctx, `SELECT id,source,started_at,COALESCE(finished_at,''),status,total_fetched,inserted,updated,error FROM ingest_runs ORDER BY started_at DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	runs := []runRecord{}
	for rows.Next() {
		var run runRecord
		var started, finished string
		if err := rows.Scan(&run.ID, &run.Source, &started, &finished, &run.Status, &run.TotalFetched, &run.Inserted, &run.Updated, &run.Error); err != nil {
			return nil, err
		}
		run.StartedAt = parseTime(started)
		run.FinishedAt = parseTime(finished)
		runs = append(runs, run)
	}
	return runs, rows.Err()
}

func (s *Store) SourceStates(ctx context.Context) ([]sourceState, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT name,COALESCE(last_started,''),COALESCE(last_finished,''),last_status,last_error,total_fetched,inserted,updated,runs FROM source_state ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	states := []sourceState{}
	for rows.Next() {
		var state sourceState
		var started, finished sql.NullString
		if err := rows.Scan(&state.Name, &started, &finished, &state.LastStatus, &state.LastError, &state.TotalFetched, &state.Inserted, &state.Updated, &state.Runs); err != nil {
			return nil, err
		}
		state.LastStarted = timePtr(started)
		state.LastFinished = timePtr(finished)
		states = append(states, state)
	}
	return states, rows.Err()
}

func (s *Store) MarkExpiredDeals(ctx context.Context) (int64, error) {
	res, err := s.db.ExecContext(ctx, `UPDATE deals SET active=0,updated_at=? WHERE active=1 AND expires_at<>'' AND expires_at<?`, nowString(), time.Now().UTC().Format(time.RFC3339))
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}
