# Pellucid Acceptance Test

This file exercises GFM features for visual verification.

## Text Formatting

This is **bold**, this is *italic*, this is ~~strikethrough~~, and this is `inline code`.

Here is a [link to CommonMark](https://commonmark.org).

## Headings

### Third Level

#### Fourth Level

##### Fifth Level

###### Sixth Level

## Blockquotes

> This is a blockquote.
>
> It can span multiple paragraphs.
>
> > And can be nested.

## Lists

### Unordered

- Item one
- Item two
  - Nested item A
  - Nested item B
- Item three

### Ordered

1. First item
2. Second item
   1. Nested first
   2. Nested second
3. Third item

### Task List

- [x] Completed task
- [ ] Incomplete task
- [ ] Another incomplete task

## Code Blocks

### Bash

```bash
#!/bin/bash
for file in *.md; do
  echo "Processing: $file"
  wc -w "$file"
done
```

### C

```c
#include <stdio.h>

int main(void) {
    int nums[] = {3, 1, 4, 1, 5};
    int sum = 0;
    for (int i = 0; i < 5; i++)
        sum += nums[i];
    printf("sum = %d\n", sum);
    return 0;
}
```

### C++

```cpp
#include <vector>
#include <algorithm>

template <typename T>
T median(std::vector<T> v) {
    std::sort(v.begin(), v.end());
    return v[v.size() / 2];
}
```

### CSS

```css
:root {
  --bg: #fdf6e3;
  --fg: #657b83;
}

body {
  font-family: system-ui, sans-serif;
  color: var(--fg);
  background: var(--bg);
}
```

### Go

```go
package main

import "fmt"

func reverse(s string) string {
    runes := []rune(s)
    for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
        runes[i], runes[j] = runes[j], runes[i]
    }
    return string(runes)
}

func main() {
    fmt.Println(reverse("Pellucid"))
}
```

### HTML

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Example</title>
</head>
<body>
  <h1>Hello, World!</h1>
</body>
</html>
```

### Java

```java
import java.util.List;
import java.util.stream.Collectors;

public class Example {
    public static void main(String[] args) {
        List<String> names = List.of("Alice", "Bob", "Charlie");
        String result = names.stream()
            .filter(n -> n.length() > 3)
            .collect(Collectors.joining(", "));
        System.out.println(result);
    }
}
```

### JavaScript

```javascript
function debounce(fn, ms) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}
```

### JSON

```json
{
  "name": "Pellucid",
  "version": "1.0.3",
  "platform": "macOS"
}
```

### Markdown

```markdown
# Example

This is **bold** and *italic* text with a [link](https://example.com).

- List item
- Another item
```

### Python

```python
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)
```

### Ruby

```ruby
class Greeter
  def initialize(name)
    @name = name
  end

  def greet
    "Hello, #{@name}!"
  end
end

puts Greeter.new("World").greet
```

### Rust

```rust
fn main() {
    let words: Vec<&str> = "hello world".split_whitespace().collect();
    for (i, word) in words.iter().enumerate() {
        println!("{i}: {word}");
    }
}
```

### Shell

```sh
#!/bin/sh
count=$(ls -1 *.md 2>/dev/null | wc -l)
printf '%d markdown files found\n' "$count"
```

### SQL

```sql
SELECT u.name, COUNT(p.id) AS post_count
FROM users u
LEFT JOIN posts p ON p.author_id = u.id
WHERE u.active = true
GROUP BY u.name
HAVING COUNT(p.id) > 5
ORDER BY post_count DESC;
```

### Swift

```swift
func greet(name: String) -> String {
    return "Hello, \(name)!"
}
```

### TOML

```toml
[package]
name = "example"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = { version = "1.0", features = ["derive"] }
```

### TypeScript

```typescript
interface Document {
  title: string;
  content: string;
  render(): Promise<void>;
}
```

### YAML

```yaml
name: pellucid
version: 1.0.3
features:
  - syntax-highlighting
  - live-reload
  - toc-sidebar
```

## Tables

| Feature | Status | Notes |
|---------|--------|-------|
| GFM rendering | Done | Core feature |
| TOC sidebar | Done | Sidebar navigation |
| File watching | Done | Live reload |
| Syntax highlighting | Done | 19 languages |

## Horizontal Rule

---

## Images

![Alt text for a test image](https://via.placeholder.com/300x100.png?text=Test+Image)

![App screenshot](screenshots/test-md.png)

## Math

```math
E = mc^2
```

```latex
\int_{0}^{\infty} e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
```

### Dollar-Sign Syntax

$$
E = mc^2
$$

$$
\int_{0}^{\infty} e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$

## PlantUML Diagrams

```plantuml
@startuml
Alice -> Bob: Hello
Bob --> Alice: Hi there
@enduml
```

## Long Content for Scroll Testing

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.

Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.
