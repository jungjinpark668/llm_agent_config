---
name: coding-rules-examples
description: Wrong-vs-right code examples for each rule in ~/.claude/rules/coding-rules.md (think before coding, simplicity first, surgical changes, goal-driven execution, class isolation, change strategy). Use when unsure how a coding rule applies to a change, or when reviewing code against the coding rules.
---

# Coding rules: worked examples

The rules themselves are in `~/.claude/rules/coding-rules.md`, which is always loaded. This skill holds only the examples, grouped by rule number.

## 1. Think Before Coding

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


## 2. Simplicity First

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


## 3. Surgical Changes

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


## 4. Goal-Driven Execution

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


## 5. Class Isolation

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


## 6. Change Strategy

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
