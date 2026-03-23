# Materials Rebuild Standards

This file replaces the discarded candidate pool and restarts materials sourcing
from the hard standards stated in the current proposal.

## Authoritative design source

See:
- `writing/proposal.tex`, Section 4.2-4.4
- `writing/Censorship/Main.tex`, content-preparation language

## Hard standards

1. The implemented study uses six arms:
   - Pro-China low dose
   - Pro-China high dose
   - Anti-China low dose
   - Anti-China high dose
   - Apolitical China
   - Non-China control

2. Required unique content banks for sourcing:
   - Pro-China political bank: 24 political articles
   - Anti-China political bank: 24 political articles
   - Apolitical China bank: 12 apolitical China-related items
   - Non-China neutral control bank: 24 non-China neutral items

3. Allowed sources:
   - Major English-language newspapers and magazines with stable URLs
   - Strongly preferred: Reuters, Associated Press, Financial Times, The Economist,
     The New York Times, The Washington Post, The Wall Street Journal, Bloomberg,
     Foreign Policy, The Guardian
   - Additional outlets are acceptable if they publish article-style prose, have
     stable source pages, and fit the tone and reading level of the intervention

4. Content rules by bank:
   - Pro-China: favorable coverage of domestic governance, development,
     infrastructure, green transition, technology, education, social policy, or
     state capacity inside China.
   - Anti-China: critical coverage of domestic governance, political performance,
     debt, regulation, repression, courts, censorship, inequality, economy, or
     social problems inside China.
   - Apolitical China: China-related culture, lifestyle, food, travel, science,
     and society without overt political framing.
   - Non-China control: neutral non-China content matched on length and
     difficulty to the treatment materials.

5. Political-treatment identification rule:
   - All political treatment items must be China-internal in their main frame.
   - Exclude articles whose causal or narrative center depends on foreign
     countries, bilateral diplomacy, international organizations, geopolitical
     competition, export markets, foreign investors, military rivalry, or
     explicit cross-national comparison.
   - Prefer items about governance, censorship, courts, inequality, economy,
     industrial policy, climate policy, education, labor, demography, and
     social change inside China itself.
   - If an item's title makes sense only because China is being evaluated
     against another country or region, or because foreign actors are reacting
     to China, it does not qualify for the political treatment bank.

6. Exclusion rules:
   - No Tiananmen
   - No Xinjiang
   - No religion or ethnic-conflict framing
   - No direct criticism of top leaders
   - No graphic or illegal content
   - No article whose main frame depends on a taboo topic

7. Format rules:
   - Article-like prose rather than listicle-heavy travel directories
   - Trimmable to roughly 800 words
   - Suitable for paired close-reading video and quiz
   - Prefer outlet pages with stable source URLs

8. Screening metadata to record for every selected item:
   - id
   - bank
   - source
   - title
   - url
   - topic
   - source_ok
   - china_focus_ok
   - valence_ok
   - taboo_screen_ok
   - format_ok
   - final_status
   - notes

## Rebuild rule

Build the materials bank from fresh sourcing and item-by-item verification only.
Every new row must be added only after being checked against the standards
above.
