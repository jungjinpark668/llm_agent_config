# Coding Rules

Behavioral guidelines to reduce common LLM coding mistakes. These bias toward caution over speed. For trivial tasks, use judgment.

---

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### Example: Hidden Assumptions

**User:** "Add a feature to export user data"

**Wrong — silently assumes scope, format, fields, location:**

```python
def export_users(format='json'):
    """Export all users to a file."""
    users = User.query.all()
    
    if format == 'json':
        with open('users.json', 'w') as f:
            json.dump([u.to_dict() for u in users], f)
    elif format == 'csv':
        with open('users.csv', 'w') as f:
            writer = csv.DictWriter(f, fieldnames=['id', 'email', 'name'])
            writer.writeheader()
            writer.writerows([u.to_dict() for u in users])
    
    return f"Exported {len(users)} users"
```

**Right — surface assumptions first:**

```
Before implementing, I need to clarify:

1. **Scope**: Export all users or filtered subset? (privacy implications)
2. **Format**: Did you mean download in browser, background job, or API endpoint?
3. **Fields**: Which user fields? (some might be sensitive)
4. **Volume**: How many users typically? (affects approach)

Simplest approach: Add an API endpoint that returns paginated JSON.
What's your preference?
```

### Example: Multiple Interpretations

**User:** "Make the search faster"

**Wrong:** Silently adds caching, indexes, and async — 200 lines of optimization without asking which "faster" matters.

**Right:** Present the options:
- **Faster response time** — add indexes/cache (~2h)
- **Higher throughput** — add async/pooling (~4h)
- **Faster perceived speed** — partial results/progressive loading (~3h)

Then ask: "Current search takes ~500ms. Which aspect matters most?"

---

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- No premature abstractions or helpers for one-time operations.
- No redundant error handling for internal code paths — only validate at system boundaries.
- No feature flags or backward-compat shims — just change the code.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Example: Over-abstraction

**User:** "Add a function to calculate discount"

**Wrong — Strategy pattern, ABC, dataclass, config for a single calculation:**

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass

class DiscountStrategy(ABC):
    @abstractmethod
    def calculate(self, amount: float) -> float:
        pass

class PercentageDiscount(DiscountStrategy):
    def __init__(self, percentage: float):
        self.percentage = percentage
    
    def calculate(self, amount: float) -> float:
        return amount * (self.percentage / 100)

class FixedDiscount(DiscountStrategy):
    def __init__(self, fixed_amount: float):
        self.fixed_amount = fixed_amount
    
    def calculate(self, amount: float) -> float:
        return min(self.fixed_amount, amount)

@dataclass
class DiscountConfig:
    strategy: DiscountStrategy
    min_purchase: float = 0.0
    max_discount: float = float('inf')

class DiscountCalculator:
    def __init__(self, config: DiscountConfig):
        self.config = config
    
    def apply_discount(self, amount: float) -> float:
        if amount < self.config.min_purchase:
            return 0
        discount = self.config.strategy.calculate(amount)
        return min(discount, self.config.max_discount)
```

**Right — one function:**

```python
def calculate_discount(amount: float, percent: float) -> float:
    return amount * (percent / 100)
```

Add complexity only when you actually need multiple discount types. If that requirement comes later, refactor then.

### Example: Speculative Features

**User:** "Save user preferences to database"

**Wrong — adds caching, validation, merging, notifications nobody asked for:**

```python
class PreferenceManager:
    def __init__(self, db, cache=None, validator=None):
        self.db = db
        self.cache = cache or InMemoryCache()
        self.validator = validator or DefaultValidator()
    
    def save(self, user_id: int, prefs: dict, 
             merge: bool = True, 
             validate: bool = True,
             notify: bool = False) -> bool:
        if validate:
            errors = self.validator.validate(prefs)
            if errors:
                raise ValidationError(errors)
        
        existing = self.get(user_id) if merge else {}
        if merge:
            existing.update(prefs)
            prefs = existing
        
        self.db.execute(
            "UPDATE users SET preferences = ? WHERE id = ?",
            (json.dumps(prefs), user_id)
        )
        
        if self.cache:
            self.cache.set(f"prefs:{user_id}", prefs)
        
        if notify:
            self.notify_preference_change(user_id, prefs)
        
        return True
```

**Right — just what was asked:**

```python
def save_preferences(db, user_id: int, preferences: dict):
    db.execute(
        "UPDATE users SET preferences = ? WHERE id = ?",
        (json.dumps(preferences), user_id)
    )
```

Add caching when performance matters, validation when bad data appears, merging when the requirement emerges.

---

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Don't add docstrings, comments, or type annotations to unchanged code.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### Example: Drive-by Refactoring

**User:** "Fix the bug where empty emails crash the validator"

**Wrong — "improves" email validation, adds username validation, changes comments, adds docstring:**

```diff
  def validate_user(user_data):
-     # Check email format
-     if not user_data.get('email'):
+     """Validate user data."""
+     email = user_data.get('email', '').strip()
+     
+     # Validate email
+     if not email:
          raise ValueError("Email required")
-     
-     # Basic email validation
-     if '@' not in user_data['email']:
+     if '@' not in email or '.' not in email.split('@')[1]:
          raise ValueError("Invalid email")
      
-     # Check username
-     if not user_data.get('username'):
+     # Validate username
+     username = user_data.get('username', '').strip()
+     if not username:
          raise ValueError("Username required")
+     if len(username) < 3:
+         raise ValueError("Username too short")
+     if not username.isalnum():
+         raise ValueError("Username must be alphanumeric")
      
      return True
```

**Right — only fix the empty email bug:**

```diff
  def validate_user(user_data):
      # Check email format
-     if not user_data.get('email'):
+     email = user_data.get('email', '')
+     if not email or not email.strip():
          raise ValueError("Email required")
      
      # Basic email validation
-     if '@' not in user_data['email']:
+     if '@' not in email:
          raise ValueError("Invalid email")
      
      # Check username
      if not user_data.get('username'):
          raise ValueError("Username required")
      
      return True
```

### Example: Style Drift

**User:** "Add logging to the upload function"

**Wrong — changes quote style, adds type hints, adds docstring, reformats whitespace, changes boolean logic:**

```diff
- def upload_file(file_path, destination):
+ def upload_file(file_path: str, destination: str) -> bool:
+     """Upload file to destination with logging."""
+     logger.info(f"Uploading {file_path} to {destination}")
+     
      try:
-         with open(file_path, 'rb') as f:
-             data = f.read()
-         
-         response = requests.post(destination, files={'file': data})
-         
-         if response.status_code == 200:
-             return True
-         else:
-             return False
+         with open(file_path, "rb") as f:
+             data = f.read()
+         response = requests.post(destination, files={"file": data})
+         success = response.status_code == 200
+         
+         if success:
+             logger.info(f"Upload successful: {file_path}")
+         else:
+             logger.error(f"Upload failed: {file_path}, status={response.status_code}")
+         
+         return success
      except Exception as e:
-         print(f"Error: {e}")
+         logger.exception(f"Upload error for {file_path}: {e}")
          return False
```

**Right — match existing style (single quotes, no type hints, same boolean pattern):**

```diff
+ import logging
+ 
+ logger = logging.getLogger(__name__)
+ 
  def upload_file(file_path, destination):
+     logger.info(f'Starting upload: {file_path}')
      try:
          with open(file_path, 'rb') as f:
              data = f.read()
          
          response = requests.post(destination, files={'file': data})
          
          if response.status_code == 200:
+             logger.info(f'Upload successful: {file_path}')
              return True
          else:
+             logger.error(f'Upload failed: {file_path}, status={response.status_code}')
              return False
      except Exception as e:
-         print(f"Error: {e}")
+         logger.exception(f'Upload error: {file_path}')
          return False
```

---

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

### Example: Vague vs. Verifiable

**User:** "Fix the authentication system"

**Wrong:** "I'll review the code, identify issues, make improvements, and test." Proceeds without clear success criteria.

**Right:** Define what "fix" means concretely:

```
To "fix authentication," I need the specific issue. 
If it's "users stay logged in after password change":

1. Write test: change password -> verify old session invalidated
   Verify: test fails (reproduces bug)
2. Implement: invalidate sessions on password change
   Verify: test passes
3. Edge cases: multiple sessions, concurrent changes
   Verify: additional tests pass
4. No regression: existing auth tests still pass
   Verify: full test suite green

What's the specific auth issue you're seeing?
```

### Example: Test-First Verification

**User:** "The sorting breaks when there are duplicate scores"

**Wrong:** Immediately changes sort logic without confirming the bug.

**Right — reproduce first, then fix:**

```python
# 1. Write a test that reproduces the issue
def test_sort_with_duplicate_scores():
    scores = [
        {'name': 'Alice', 'score': 100},
        {'name': 'Bob', 'score': 100},
        {'name': 'Charlie', 'score': 90},
    ]
    
    result = sort_scores(scores)
    
    assert result[0]['score'] == 100
    assert result[1]['score'] == 100
    assert result[2]['score'] == 90

# Verify: run test 10 times -> fails with inconsistent ordering

# 2. Fix with stable sort
def sort_scores(scores):
    return sorted(scores, key=lambda x: (-x['score'], x['name']))

# Verify: test passes consistently
```

---

## 5. Class Isolation

**Each class does ONLY its own job. Orchestration belongs outside.**

- By default, do NOT instantiate or call another class inside a class.
- Assume the orchestrating script/test has already prepared all input data — classes receive ready-to-use data via method arguments or constructor.
- Orchestration (calling classes in sequence, passing outputs between them) belongs in the main script/test, not inside classes.
- If the code generates a plot, default to PNG output. Ask the user whether to also create SVG, EPS, or EMF files.

**Exception** — calling another class internally requires clear justification covering all three:
1. **Why** — what problem does it solve that external orchestration cannot?
2. **How it improves quality** — what readability, correctness, or performance gain?
3. **Why it's inevitable** — why is passing pre-computed data from the script not viable?

### Example: Hidden Coupling

**User:** "Add a class to generate a report from analyzed data"

**Wrong — `ReportGenerator` instantiates and calls `DataAnalyzer` internally:**

```python
class ReportGenerator:
    def __init__(self, raw_data):
        self.analyzer = DataAnalyzer(raw_data)
    
    def generate(self):
        stats = self.analyzer.compute_stats()
        trends = self.analyzer.find_trends()
        
        return {
            'summary': self._format_summary(stats),
            'trends': self._format_trends(trends),
        }
    
    def _format_summary(self, stats):
        return f"Mean: {stats['mean']:.2f}, Std: {stats['std']:.2f}"
    
    def _format_trends(self, trends):
        return [f"{t['name']}: {t['direction']}" for t in trends]
```

**Right — orchestration script passes pre-computed data:**

```python
class ReportGenerator:
    def __init__(self, stats, trends):
        self.stats = stats
        self.trends = trends
    
    def generate(self):
        return {
            'summary': self._format_summary(),
            'trends': self._format_trends(),
        }
    
    def _format_summary(self):
        return f"Mean: {self.stats['mean']:.2f}, Std: {self.stats['std']:.2f}"
    
    def _format_trends(self):
        return [f"{t['name']}: {t['direction']}" for t in self.trends]

# main.py — orchestration lives here
analyzer = DataAnalyzer(raw_data)
stats = analyzer.compute_stats()
trends = analyzer.find_trends()

report = ReportGenerator(stats, trends)
print(report.generate())
```

---

## 6. Change Strategy

**Search before writing. Extend before duplicating.**

When modifying existing code:
- Search for existing methods that already do what you need before writing new ones.
- Integrate into existing methods via optional parameters rather than duplicating logic.
- Only create new functions when integration would hurt readability or is technically impossible.
- When modifying, ensure original behavior still works — the default path must remain unchanged.

### Example: Duplication vs. Extension

**User:** "Add support for weighted averages in the stats module"

**Wrong — creates a new function that duplicates most of `compute_average`:**

```python
def compute_average(values):
    return sum(values) / len(values)

def compute_weighted_average(values, weights):
    total = sum(v * w for v, w in zip(values, weights))
    return total / sum(weights)
```

**Right — extend the existing function with an optional parameter:**

```python
def compute_average(values, weights=None):
    if weights is not None:
        return sum(v * w for v, w in zip(values, weights)) / sum(weights)
    return sum(values) / len(values)
```

Original callers (`compute_average(values)`) still work identically. New callers pass `weights`.

---

## 7. Naming & Structure

**Follow the project's existing conventions. Don't introduce a second style.**

- If the codebase uses `snake_case`, use `snake_case`. If it uses `camelCase`, use `camelCase`.
- Match existing patterns for file organization, module layout, and import style.
- If the project has no existing code (new project), ask the user which style to reference — or suggest a convention and confirm before writing.
- Never mix naming styles within a project.

---

## 8. Comment Style

**Default Python docstring format is Sphinx (`reST`).**

When a docstring is warranted (public API, non-obvious parameters), use Sphinx style:

```python
def compute_average(values, weights=None):
    """Compute arithmetic or weighted average.

    :param values: Sequence of numeric values.
    :param weights: Optional sequence of weights. If None, computes unweighted average.
    :returns: The computed average.
    :raises ValueError: If values is empty.
    """
```

Remember: the default is still **no comments**. Only add docstrings when the WHY or interface is non-obvious. Sphinx style applies when you do write one.

---

## Anti-Patterns Summary

| Principle | Anti-Pattern | Fix |
|-----------|-------------|-----|
| Think Before Coding | Silently assumes format, fields, scope | List assumptions explicitly, ask for clarification |
| Simplicity First | Strategy pattern for single calculation | One function until complexity is actually needed |
| Surgical Changes | Reformats quotes, adds type hints while fixing bug | Only change lines that fix the reported issue |
| Goal-Driven | "I'll review and improve the code" | "Write test for bug X -> make it pass -> verify no regressions" |
| Class Isolation | Class instantiates another class internally | Orchestration script passes pre-computed data |
| Change Strategy | New function duplicating existing logic | Extend existing method with optional parameter |
| Naming & Structure | Introduces camelCase into a snake_case project | Match existing conventions; ask if new project |
| Comment Style | Google-style or no-format docstrings in Python | Use Sphinx (reST) when docstrings are warranted |

## Key Insight

The overcomplicated examples aren't obviously wrong — they follow design patterns and best practices. The problem is **timing**: they add complexity before it's needed, which makes code harder to understand, introduces more bugs, takes longer to implement, and is harder to test.

Good code solves today's problem simply, not tomorrow's problem prematurely. Simple versions can always be refactored later when complexity is actually needed.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
