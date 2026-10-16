# ============================================================================
# CONSTANTS
# ============================================================================

# A4 dimensions in points (72 DPI)
const A4_WIDTH = 595
const A4_HEIGHT = 842

# Conversion factors
const DPI = 96
const CM_TO_POINTS = 28.35  # 72 / 2.54

# URLs
const RESUME_JSON_URL = "https://gist.githubusercontent.com/shaoyanji/b7b844737e6469c9160bf41aa8970068/raw/resume.json"
const FLAKE_URL = "https://gist.githubusercontent.com/shaoyanji/98577da48a92cc6ed9dc3a888cbdb177/raw/flake.nix.cv"
const TEMPLATES = {
    typst_cv: "https://gist.githubusercontent.com/shaoyanji/971a57b292397d417aafabbe3b2cd32b/raw/Ji_Matt_CV.typ",
    typst_standalone: "https://gist.githubusercontent.com/shaoyanji/83828d5a6cf022478dc4b898ac9e7601/raw/standalone-cv.typ",
    lebenslauf_json: "https://gist.githubusercontent.com/shaoyanji/541b117a49173c4ba8c23b5d126b1fd1/raw/lebenslauf.json",
    coverletter_typst: "https://gist.githubusercontent.com/shaoyanji/42dde105818fb25907b9e169636e4aa3/raw/coverletter_template.typ",
}

# Fonts
const FONTS = {
    regular: "JetBrainsMonoNFM-Regular",
    bold: "JetBrainsMonoNFM-Bold",
    fallback: "Courier",
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Check if resume.json exists in current directory
def has_resume_json []: nothing -> bool {
    (ls | get name | any { $in == "resume.json" })
}

# Safe HTTP get with error handling
def safe_http_get [url: string, fallback_msg: string = "Failed to fetch resource"]: nothing -> any {
    try {
        http get $url
    } catch {
        error make { msg: $"($fallback_msg): ($url)" }
    }
}

# Save file with error handling
def safe_save [data: any, path: string, --force(-f)]: nothing -> nothing {
    try {
        if $force {
            $data | save -f $path
        } else {
            $data | save $path
        }
    } catch {
        error make { msg: $"Failed to save ($path)" }
    }
}

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

# Imports resume.json from gist or uses local cache
export def "jobby importjson" []: nothing -> record {
    if (has_resume_json) {
        "using cached resume.json" | print
    } else {
        safe_http_get $RESUME_JSON_URL "Failed to fetch resume.json"
            | safe_save --force $in resume.json
    }
    open resume.json
}

# ============================================================================
# PDF GENERATION - GHOSTSCRIPT (json2pdf)
# ============================================================================

export def "jobby json2pdf" []: nothing -> nothing {
    let cv = jobby importjson
    let fontsize = 30
    let gr = (1 + (5 | math sqrt)) / 2
    let fibfont = {|s: int| ($fontsize / $gr ** $s) | into int }
    let font = {|s: int| $"/oRCA (do $fibfont $s) selectfont" }
    let lm = 50
    let top = 842 - $lm
    let A4 = $"($lm) ($top) moveto"

    let render = {|x| $"\(($x.item | to text)\) show" }
    let struct = {
        | l: list, s |
        $l
            | enumerate
            | each { |x|
                $" 0 -(do $fibfont $s) rmoveto "
                + (do $render $x)
                + $" -(($x.item | to text | str stats | get chars) * (do $fibfont $s) * 3 / 5) 0 rmoveto"
            }
            | prepend (do $font $s)
    }
    let l2psstr = {
        | l: list |
        $l
            | enumerate
            | each { |x| (char space) + (do $render $x) + (char space) }
    }
    let se = { |x| $"\) ($x | to text) \(" }

    let font0 = {|x| do $se (do $struct $x 0) }
    let font1 = {|x| do $se (do $struct $x 1) }
    let font2 = {|x| do $se (do $struct $x 2) }
    let font3 = {|x| do $se (do $struct $x 3) }
    let font4 = {|x| do $se (do $struct $x 4) }

    $A4
        | append (
            [$cv.basics.name]
                | do $struct $in 0
        )
        | append (
            [
                $cv.basics.phone
                $cv.basics.email
                $cv.basics.location.address
                $cv.basics.location.city
                [$cv.basics.location.countryCode $cv.basics.location.postalCode]
            ]
            | do $struct $in 2
        )
        | append (
            $cv.work
                | each {
                    |x|
                        | append (do $font1 [$x.name])
                        | append (do $font2 [$x.position])
                        | append (do $font3 [[
                            "from" $x.startDate
                            "to" $x.endDate
                        ]])
                        | append (do $font3 $x.highlights)
                }
                | do $l2psstr $in
        )
        | append (
            $cv.projects
                | each {
                    |x|
                        | append (do $font1 [$x.name])
                        # | append (do $font2 [$x.entity])
                        | append (do $font3 [[
                            "from" $x.startDate
                            "to" $x.endDate
                        ]])
                }
                | do $l2psstr $in
        )
        | append (
            $cv.education
                | each {
                    |x|
                        | append (do $font1 [$x.institution])
                        | append (do $font2 [$x.studyType])
                        | append (do $font3 [[
                            "from" $x.startDate
                            "to" $x.endDate
                        ]])
                }
                | do $l2psstr $in
        )
        | append (
            $cv.languages
                | each {
                    |x|
                        | append (do $font1 [$x.language])
                        | append (do $font2 [$x.fluency])
                }
                | do $l2psstr $in
        )
        | str replace --all "\(\n\) show" ""
        | str replace --all "\(\n\)" ""
        | str replace --all "\(\)" ""
        | str replace --all "\n" " "
        | to text
        | ps2pdf - resume.pdf
}

# ============================================================================
# TYPST RESUME GENERATION
# ============================================================================

export def "jobby resume typix" []: nothing -> nothing {
    let flake = safe_http_get $FLAKE_URL "Failed to fetch flake.nix"
    let template = safe_http_get $TEMPLATES.typst_cv "Failed to fetch Typst template"

    jobby importjson
    safe_save --force $flake "flake.nix"
    safe_save --force $template "Ji_Matt_CV.typ"

    nix run .#build
}

export def "jobby resume typst" []: nothing -> nothing {
    let template = safe_http_get $TEMPLATES.typst_standalone "Failed to fetch standalone template"

    jobby importjson
    safe_save --force $template "Ji_Matt_CV.typ"

    # Fetch and save web resources
    typst query --input prequery-fallback=true --field value standalone-cv.typ '<web-resource>'
        | from json
        | each { |x|
            safe_http_get $x.url $"Failed to fetch resource ($x.path)"
                | safe_save --force $in $x.path
        }

    typst c Ji_Matt_CV.typ
}


# Translate English resume.json to German, then compile
export def "jobby deutsch" []: nothing -> nothing {
    let cv = jobby importjson
    let template = safe_http_get $TEMPLATES.typst_standalone "Failed to fetch standalone template"

    def t [s: string]: nothing -> string {
        if ($s | str trim | str length) == 0 { return $s }
        $s | trans -brief :de | str trim
    }

    def tl [list: list]: nothing -> list {
        $list | each { |item| t $item }
    }

    # Translate each section with explicit variable scope
    let skills_de = $cv.skills | each { |skill|
        { name: (t $skill.name), keywords: (tl $skill.keywords), level: $skill.level }
    }

    let work_de = $cv.work | each { |job|
        $job | update name (t $job.name) | update position (t $job.position) | update summary (t $job.summary) | update highlights (tl $job.highlights)
    }

    let projects_de = $cv.projects | each { |proj|
        $proj | update name (t $proj.name) | update description (t $proj.description) | update entity (t $proj.entity) | update highlights (tl $proj.highlights)
    }

    let education_de = $cv.education | each { |school|
        $school | update institution (t $school.institution) | update studyType (t $school.studyType) | update courses (tl $school.courses)
    }

    let languages_de = $cv.languages | each { |lang|
        {
            language: (if $lang.language == "English" { "Englisch" } else if $lang.language == "German" { "Deutsch" } else { t $lang.language })
            fluency: (if $lang.fluency == "Native speaker" { "Muttersprache" } else if $lang.fluency == "Fluent" { "Fließend" } else { t $lang.fluency })
        }
    }

    let cv_de = $cv
        | update basics.label (t $cv.basics.label)
        | update basics.altLabels (tl $cv.basics.altLabels)
        | update basics.summary (t $cv.basics.summary)
        | update skills $skills_de
        | update work $work_de
        | update projects $projects_de
        | update education $education_de
        | update languages $languages_de
        | upsert meta { { language: "de" } }

    $cv_de | to json | safe_save --force $in "lebenslauf.json"
    safe_save --force $template "Ji_Matt_CV.typ"

    typst query --input json=lebenslauf.json --input prequery-fallback=true --field value Ji_Matt_CV.typ '<web-resource>'
        | from json
        | each { |x|
            safe_http_get $x.url $"Failed to fetch resource ($x.path)"
                | safe_save --force $in $x.path
        }

    typst c --input json=lebenslauf.json Ji_Matt_CV.typ
}

# ============================================================================
# COVER LETTER FUNCTIONS
# ============================================================================

# Generate cover letter via LLM + Typst template (with signature)
export def "jobby coverletter source" []: nothing -> nothing {
    let cv = jobby importjson
    let template = safe_http_get $TEMPLATES.coverletter_typst "Failed to fetch cover letter template"

    let prompt = "Write a job cover letter in German. Compose a brief and impactful cover letter based on the provided job description and resume. The letter should be no longer than three paragraphs and should be written in a professional, yet conversational tone. Avoid using any placeholders, and ensure that the letter flows naturally and is tailored to the job. Analyze the job description to identify key qualifications and requirements which are listed in yaml after the the job description. Introduce the candidate succinctly, aligning their career objectives with the role. Highlight relevant skills and experiences from the resume that directly match the job's demands, using specific examples to illustrate these qualifications. Reference notable aspects of the company, such as its mission or values, that resonate with the candidate's professional goals. Conclude with a strong statement of why the candidate is a good fit for the position, expressing a desire to discuss further. Please write the cover letter in a way that directly addresses the job role and the company's characteristics, ensuring it remains concise and engaging without unnecessary embellishments. The letter should be formatted into paragraphs and should not include a greeting or signature."

    let job_desc = (input "Job Description> ")
    let company_name = (input "Company name> ")
    let company_dept = (input "Department/HR> ")
    let company_loc = (input "Company location (city)> ")
    let subject = (input -d 'Bewerbung als ...' "Subject line> ")

    let cover_letter_text = (llm $"($prompt)\n\nResume:\n($cv | to text)\n\nJob Description:\n($job_desc)" | fmt -w 72)

    # Download signature image (Typst cannot fetch remote URLs)
    let sig_url = "https://res.cloudinary.com/de1eajx01/image/upload/v1765739484/qa7exxxy8xvzzkmjgyxn.png"
    let sig_local = "coverletter_signature.png"
    http get $sig_url | save -f $sig_local

    safe_save --force $template "coverletter_template.typ"

    let n = $cv.basics.name
    let a = $cv.basics.location.address
    let c = $"($cv.basics.location.countryCode) ($cv.basics.location.postalCode)"
    let p = $cv.basics.phone
    let e = $cv.basics.email
    let ci = $cv.basics.location.city

    let args = [
        "--input", $"name=($n)",
        "--input", $"address=($a)",
        "--input", $"code=($c)",
        "--input", $"phone=($p)",
        "--input", $"email=($e)",
        "--input", $"company=($company_name)",
        "--input", $"dept=($company_dept)",
        "--input", $"loc=($company_loc)",
        "--input", $"city=($ci)",
        "--input", $"subject=($subject)",
        "--input", $"body=($cover_letter_text)",
        "--input", $"sig=($sig_local)",
        "coverletter_template.typ",
        "Ji_Matt_Cover_Letter.pdf"
    ]
    ^typst c ...$args

    jobby coverletter render
}

# Re-generate cover letter with edited body text
export def "jobby coverletter edit" []: nothing -> nothing {
    let body = (gum write --placeholder "Write or paste cover letter body...")
    let sig_local = "coverletter_signature.png"
    if not ($sig_local | path exists) {
        http get "https://res.cloudinary.com/de1eajx01/image/upload/v1765739484/qa7exxxy8xvzzkmjgyxn.png" | save -f $sig_local
    }
    let cv = jobby importjson
    let company_name = (input "Company name> ")
    let subject = (input -d 'Bewerbung als ...' "Subject line> ")

    safe_http_get $TEMPLATES.coverletter_typst "Failed to fetch template" | save -f "coverletter_template.typ"

    let n = $cv.basics.name
    let a = $cv.basics.location.address
    let c = $"($cv.basics.location.countryCode) ($cv.basics.location.postalCode)"
    let p = $cv.basics.phone
    let e = $cv.basics.email
    let ci = $cv.basics.location.city

    let args = [
        "--input", $"name=($n)",
        "--input", $"address=($a)",
        "--input", $"code=($c)",
        "--input", $"phone=($p)",
        "--input", $"email=($e)",
        "--input", $"company=($company_name)",
        "--input", "dept=Personalabteilung",
        "--input", "loc=",
        "--input", $"city=($ci)",
        "--input", $"subject=($subject)",
        "--input", $"body=($body)",
        "--input", $"sig=($sig_local)",
        "coverletter_template.typ",
        "Ji_Matt_Cover_Letter.pdf"
    ]
    ^typst c ...$args

    jobby coverletter render
}

export def "jobby coverletter render" []: nothing -> nothing {
    mupdf Ji_Matt_Cover_Letter.pdf
}

export def "jobby coverletter" []: nothing -> nothing {
    jobby coverletter source
}

# Legacy pdfcpu-based cover letter (no signature rendering issues)
export def "jobby coverletter pdfcpu" []: nothing -> nothing {
    let cv = jobby importjson
    let font_size = 10
    let margin_left_cm = 2.5
    let margin_top_cm = 4.5
    let margin_right_cm = 2

    # Convert cm to points
    let lm = ($margin_left_cm * $CM_TO_POINTS)
    let tm = ($margin_top_cm * $CM_TO_POINTS)
    let rm = ($margin_right_cm * $CM_TO_POINTS)

    let prompt = "Write a job cover letter in German. Compose a brief and impactful cover letter based on the provided job description and resume. The letter should be no longer than three paragraphs and should be written in a professional, yet conversational tone. Avoid using any placeholders, and ensure that the letter flows naturally and is tailored to the job. Analyze the job description to identify key qualifications and requirements which are listed in yaml after the the job description. Introduce the candidate succinctly, aligning their career objectives with the role. Highlight relevant skills and experiences from the resume that directly match the job's demands, using specific examples to illustrate these qualifications. Reference notable aspects of the company, such as its mission or values, that resonate with the candidate's professional goals. Conclude with a strong statement of why the candidate is a good fit for the position, expressing a desire to discuss further. Please write the cover letter in a way that directly addresses the job role and the company's characteristics, ensuring it remains concise and engaging without unnecessary embellishments. The letter should be formatted into paragraphs and should not include a greeting or signature."

    # Build contact info block
    let contact_lines = [
        $cv.basics.name,
        $cv.basics.location.address,
        $"($cv.basics.location.countryCode) ($cv.basics.location.postalCode)",
        $cv.basics.phone,
        $cv.basics.email,
    ] | str join "\n"

    # Calculate email position
    let email_x = ($A4_WIDTH - $rm - ($cv.basics.email | str length) * 12 * 0.5)
    let email_y = ($A4_HEIGHT - 5 * $font_size)

    # Get job description from user
    let job_desc = (input "Job Description> ")
    let cover_letter_text = (llm $"($prompt) ($cv | to text) ($job_desc)" | fmt -w 72)

    # Build PDFCPU configuration
    {
        paper: A4,
        pages: {
            1: {
                content: {
                    text: [
                        {
                            font: { name: $FONTS.regular, size: $font_size },
                            value: $contact_lines,
                            pos: [($email_x) ($email_y)],
                        },
                        {
                            font: { name: $FONTS.regular, size: $font_size },
                            value: $"Freiburg, (date now | format date "%d.%m.%Y")",
                            pos: [$lm ($A4_HEIGHT - 8 * $font_size)],
                        },
                        {
                            font: { name: $FONTS.regular, size: $font_size },
                            value: (input -d '\n\n\n' "Address> "),
                            pos: [$lm ($A4_HEIGHT - 12 * $font_size)],
                        },
                        {
                            font: { name: $FONTS.bold, size: $font_size },
                            value: (input -d 'Betreff: Bewerbung' "Subject> "),
                            pos: [$lm ($A4_HEIGHT - 14 * $font_size)],
                        },
                        {
                            font: { name: $FONTS.regular, size: $font_size },
                            value: $"Sehr geehrte Damen und Herren,\n\n($cover_letter_text)",
                            pos: [$lm (14 * $font_size)],
                        },
                        {
                            font: { name: $FONTS.regular, size: $font_size },
                            value: "Mit freundlichen Grüßen,\n\n\n\nMatt Ji",
                            pos: [$lm (2 * $font_size)],
                        },
                    ],
                    image: [
                        {
                            src: "https://res.cloudinary.com/de1eajx01/image/upload/v1765739484/qa7exxxy8xvzzkmjgyxn.png",
                            pos: [$lm (4 * $font_size)],
                        },
                    ],
                },
            },
        },
    }
        | safe_save --force $in "pdfcpu.json"

    pdfcpu create pdfcpu.json Ji_Matt_Cover_Letter.pdf
    jobby coverletter render
}

export def "jobby coverletter compile" []: nothing -> nothing {
    pdfcpu create pdfcpu.json Ji_Matt_Cover_Letter.pdf
}

# ============================================================================
# PDFCPU RESUME GENERATION
# ============================================================================

export def "jobby resume pdfcpu" []: nothing -> nothing {
    let cv = jobby importjson

    # Check for available font
    let font = if (pdfcpu fonts list | to text | str contains $FONTS.regular) {
        $FONTS.regular
    } else {
        $FONTS.fallback
    }

    let golden_ratio = 1.61
    let font_size = 12
    let margin_left_cm = 0.5
    let margin_top_cm = 4.5
    let margin_right_cm = 2

    # Convert margins to points
    let lm = ($margin_left_cm * $CM_TO_POINTS | into int)
    let tm = ($margin_top_cm * $CM_TO_POINTS)
    let rm = ($margin_right_cm * $CM_TO_POINTS | into int)

    # Build contact info block
    let contact_info = [
        $cv.basics.name,
        $cv.basics.location.address,
        $"($cv.basics.location.countryCode) ($cv.basics.location.postalCode)",
        $cv.basics.phone,
        $cv.basics.email,
    ] | str join "\n"

    # Build PDFCPU configuration
    {
        paper: A4,
        pages: {
            1: {
                content: {
                    text: [
                        {
                            font: { name: $font, size: ($font_size * $golden_ratio ** 2 | into int) },
                            value: $cv.basics.name,
                            pos: [$lm $A4_HEIGHT],
                        },
                        {
                            font: { name: $font, size: $font_size },
                            value: $contact_info,
                            pos: [$lm ($A4_HEIGHT - (12 * $font_size))],
                        },
                    ],
                    image: [
                        {
                            src: "https://jisifu.envs.net/content/pics/profile.svg",
                            pos: [($A4_WIDTH - $rm) $A4_HEIGHT],
                            align: top,
                            height: 100,
                        },
                    ],
                },
            },
        },
    }
        | safe_save --force $in "pdfcpu.json"

    pdfcpu create pdfcpu.json Ji_Matt_CV.pdf
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

export def "jobby resume" []: nothing -> nothing {
    jobby resume typst
    mupdf Ji_Matt_CV.pdf
}