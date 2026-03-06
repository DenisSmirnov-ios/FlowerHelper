# Contributing

## Как вносить изменения
1. Создайте ветку от `main`.
2. Делайте небольшие логичные коммиты.
3. Перед PR убедитесь, что проект собирается.

## Локальная проверка
```bash
xcodebuild -project GreenFriend.xcodeproj -scheme GreenFriend -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

## Pull Request
- Кратко опишите цель изменений.
- Приложите скриншоты для UI-изменений.
- Укажите, как проверяли изменения.
