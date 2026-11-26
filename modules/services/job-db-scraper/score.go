// Deterministic role-match scoring, ported from scripts/task/jobsearch-sweep.py:
// the same lane/out/agency/location patterns, so a row scored here reads the
// same as a row the sweep files. No model, no network — the same input always
// produces the same score, which is what makes the surface sortable.
package main

import (
	"encoding/json"
	"regexp"
	"strings"
)

var (
	laneRe = regexp.MustCompile(`(?i)(devops|dev[ -]ops|\bsre\b|site[ -]reliab|platform[ -]?(engineer|infra|operations)` +
		`|infrastructure[ -]?(engineer|operations|specialist|architect)` +
		`|cloud[ -]?(platform|engineer|infrastructure|operations|native)` +
		`|kubernetes|\bk8s\b|linux[ -](engineer|administrator|systems)|openshift)`)
	outRe = regexp.MustCompile(`(?i)(duales studium|studium|hochschule|embedded|softwareentwickler|software developer` +
		`|backend|frontend|fullstack|support|kundensupport|sales|vertrieb|\berp\b|\bsap\b` +
		`|datev|windows|m365|sharepoint|citrix|helpdesk|first[ -]level|werkstudent` +
		`|praktik|ausbildung|trainee|elektro|maschinenbau|mechanical|bauwesen|junior)`)
	agencyRe = regexp.MustCompile(`(?i)(consult|beratung|recruit|personalberatung|staffing|systemhaus` +
		`|managed services|outsourcing|dienstleist)`)
	badLocRe = regexp.MustCompile(`(?i)(us only|usa only|united states only|americas|asia|india|philippines` +
		`|canada only|latam|africa|australia|new zealand|japan|china)`)
	goodLocRe = regexp.MustCompile(`(?i)(germany|deutschland|berlin|munich|münchen|hamburg|stuttgart|köln|koeln` +
		`|frankfurt|düsseldorf|duesseldorf|leipzig|dresden|nürnberg|nuernberg` +
		`|karlsruhe|bremen|essen|hannover|bonn|mannheim|augsburg|wien|vienna|graz` +
		`|linz|zürich|zurich|basel|bern|europe|emea|anywhere|worldwide|remote)`)
)

// scorePosting rates a posting 0..100 from a base of 50. Lane membership is a
// classification, not a score: OUT wins over LANE because a "DevOps-Engineer
// (Ausbildung)" is out, however many lane words it carries.
func scorePosting(p Posting) (lane string, score int, reasons []string) {
	text := p.Title + " " + p.Description
	locText := p.Location + " " + p.Title + " " + p.Description
	score = 50
	laneHit := laneRe.MatchString(text)
	outHit := outRe.MatchString(text)
	switch {
	case laneHit:
		score += 30
		reasons = append(reasons, "lane:+30")
	case outHit:
		score -= 40
		reasons = append(reasons, "out:-40")
	}
	if agencyRe.MatchString(p.Employer + " " + text) {
		score -= 15
		reasons = append(reasons, "agency:-15")
	}
	if badLocRe.MatchString(locText) {
		score -= 25
		reasons = append(reasons, "badloc:-25")
	} else if goodLocRe.MatchString(locText) {
		score += 10
		reasons = append(reasons, "goodloc:+10")
	}
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	switch {
	case outHit:
		lane = "out"
	case laneHit:
		lane = "in"
	default:
		lane = "unclear"
	}
	return lane, score, reasons
}

// dedupeKey is the normalized (employer, title) pair: umlauts folded, legal
// suffixes and punctuation stripped, so "Muster GmbH" and "Muster" are one
// employer and a reposted role updates rather than duplicates.
func dedupeKey(employer, title string) string {
	e := normName(employer)
	t := normName(title)
	if e == "" || t == "" {
		return ""
	}
	return e + "|" + t
}

var legalSuffixes = []string{"gmbh", "ag", "se", "kg", "ohg", "ug", "ltd", "inc", "llc", "corp", "co"}

func normName(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	replacer := strings.NewReplacer("ä", "ae", "ö", "oe", "ü", "ue", "ß", "ss")
	s = replacer.Replace(s)
	var b strings.Builder
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z' || r >= '0' && r <= '9':
			b.WriteRune(r)
		default:
			b.WriteRune(' ')
		}
	}
	words := strings.Fields(b.String())
	out := words[:0]
	for _, w := range words {
		strip := false
		for _, suf := range legalSuffixes {
			if w == suf {
				strip = true
				break
			}
		}
		if !strip {
			out = append(out, w)
		}
	}
	return strings.Join(out, " ")
}

func marshalReasons(reasons []string) string {
	if len(reasons) == 0 {
		return "[]"
	}
	b, _ := json.Marshal(reasons)
	return string(b)
}

func unmarshalReasons(s string) []string {
	var out []string
	if json.Unmarshal([]byte(s), &out) != nil || out == nil {
		return []string{}
	}
	return out
}
