// ============================================================================
// kstd.h — Freestanding C++ Standard Library Compatibility Layer
// ============================================================================
// Provides the STL types that the Flux interpreter needs but that are NOT
// present in the transpiler's freestanding preamble:
//   - std::unordered_map<K,V>  (open-addressing hash table)
//   - std::shared_ptr<T>       (thin wrapper — no refcount needed, bump alloc)
//   - std::function<T>         (type-erased callable)
//   - std::pair<A,B>           (simple pair)
//   - std::set<T>              (sorted array)
//   - std::ostringstream       (stub for string building)
//   - std::runtime_error       (error container, no throw)
//   - std::enable_shared_from_this<T> (stub)
//   - std::initializer_list<T> (compiler-provided)
//
// These types all allocate from flux_heap_alloc() (bump allocator).
// Since kfree is a no-op, destructors don't free memory.
// This is acceptable for short-lived game script execution.
//
// REQUIRES: The transpiler freestanding preamble (FluxString, FluxList, etc.)
//           must be defined BEFORE this header is included.
// ============================================================================

#pragma once

#include <stdint.h>
#include <stddef.h>
#include <initializer_list>

// Forward declare the heap allocator (provided by transpiler preamble)
extern void* flux_heap_alloc(size_t bytes);

// Forward declare memcpy/memset/memmove (provided by transpiler preamble)
extern "C" {
    void* memcpy(void* dest, const void* src, size_t n);
    void* memset(void* s, int c, size_t n);
    void* memmove(void* dest, const void* src, size_t n);
    int   memcmp(const void* s1, const void* s2, size_t n);
    size_t strlen(const char* s);
    int   strcmp(const char* s1, const char* s2);
}

namespace std {

// ============================================================================
// std::pair<A,B>
// ============================================================================
template<class A, class B>
struct pair {
    A first;
    B second;

    pair() : first(), second() {}
    pair(const A& a, const B& b) : first(a), second(b) {}
};

template<class A, class B>
pair<A,B> make_pair(const A& a, const B& b) {
    return pair<A,B>(a, b);
}

// ============================================================================
// std::shared_ptr<T> — Thin wrapper, NO reference counting
// ============================================================================
// In StratOS's bump allocator, memory is never freed. So shared_ptr is just
// a raw pointer wrapper that provides the same API.
// ============================================================================
template<class T>
class shared_ptr {
    T* ptr_;
public:
    shared_ptr() : ptr_(nullptr) {}
    shared_ptr(T* p) : ptr_(p) {}
    shared_ptr(const shared_ptr& o) : ptr_(o.ptr_) {}
    shared_ptr& operator=(const shared_ptr& o) { ptr_ = o.ptr_; return *this; }
    shared_ptr& operator=(T* p) { ptr_ = p; return *this; }

    T* get() const { return ptr_; }
    T& operator*() const { return *ptr_; }
    T* operator->() const { return ptr_; }
    explicit operator bool() const { return ptr_ != nullptr; }

    bool operator==(const shared_ptr& o) const { return ptr_ == o.ptr_; }
    bool operator!=(const shared_ptr& o) const { return ptr_ != o.ptr_; }
    bool operator==(decltype(nullptr)) const { return ptr_ == nullptr; }
    bool operator!=(decltype(nullptr)) const { return ptr_ != nullptr; }

    void reset() { ptr_ = nullptr; }
    void reset(T* p) { ptr_ = p; }
};

template<class T, class... Args>
shared_ptr<T> make_shared(Args&&... args) {
    void* mem = flux_heap_alloc(sizeof(T));
    if (!mem) return shared_ptr<T>(nullptr);
    T* obj = new(mem) T(static_cast<Args&&>(args)...);
    return shared_ptr<T>(obj);
}

// Static pointer cast — just reinterpret (safe because we only upcast/downcast)
template<class T, class U>
shared_ptr<T> static_pointer_cast(const shared_ptr<U>& r) {
    return shared_ptr<T>(static_cast<T*>(r.get()));
}

template<class T, class U>
shared_ptr<T> dynamic_pointer_cast(const shared_ptr<U>& r) {
    // Without RTTI, this is a static cast. Caller must ensure type safety.
    return shared_ptr<T>(static_cast<T*>(r.get()));
}

// ============================================================================
// std::enable_shared_from_this<T> — Stub (no-op in bump allocator world)
// ============================================================================
template<class T>
class enable_shared_from_this {
protected:
    shared_ptr<T> shared_from_this() {
        return shared_ptr<T>(static_cast<T*>(this));
    }
};

// ============================================================================
// std::unordered_map<K,V> — Open-addressing hash table
// ============================================================================
// Uses linear probing. Allocates from bump heap. Grows by doubling.
// K must support operator== and a hash function must exist.
// ============================================================================

// Hash function for FluxString (FNV-1a)
inline size_t hash_string(const char* data, size_t len) {
    size_t hash = 14695981039346656037ULL;
    for (size_t i = 0; i < len; i++) {
        hash ^= (size_t)(unsigned char)data[i];
        hash *= 1099511628211ULL;
    }
    return hash;
}

// Generic hash — specializations below
template<class K> struct hash {};

// For int types
template<> struct hash<int32_t> {
    size_t operator()(int32_t k) const { return (size_t)k * 2654435761ULL; }
};
template<> struct hash<int64_t> {
    size_t operator()(int64_t k) const { return (size_t)k * 2654435761ULL; }
};
template<> struct hash<uint32_t> {
    size_t operator()(uint32_t k) const { return (size_t)k * 2654435761ULL; }
};
template<> struct hash<size_t> {
    size_t operator()(size_t k) const { return k * 2654435761ULL; }
};

// For bool
template<> struct hash<bool> {
    size_t operator()(bool k) const { return k ? 1 : 0; }
};

template<class K, class V>
class unordered_map {
    struct Entry {
        K key;
        V value;
        bool occupied;
        bool deleted;

        Entry() : key(), value(), occupied(false), deleted(false) {}
    };

    Entry* buckets_;
    size_t capacity_;
    size_t size_;

    size_t hash_key(const K& key) const {
        hash<K> h;
        return h(key);
    }

    size_t probe(const K& key) const {
        size_t idx = hash_key(key) & (capacity_ - 1);
        size_t start = idx;
        while (buckets_[idx].occupied || buckets_[idx].deleted) {
            if (buckets_[idx].occupied && buckets_[idx].key == key) return idx;
            idx = (idx + 1) & (capacity_ - 1);
            if (idx == start) break;
        }
        return idx;
    }

    void grow() {
        size_t newCap = capacity_ * 2;
        if (newCap < 16) newCap = 16;
        Entry* newBuckets = (Entry*)flux_heap_alloc(sizeof(Entry) * newCap);
        if (!newBuckets) return;
        for (size_t i = 0; i < newCap; i++) {
            newBuckets[i].occupied = false;
            newBuckets[i].deleted = false;
            new(&newBuckets[i].key) K();
            new(&newBuckets[i].value) V();
        }
        // Rehash existing entries
        for (size_t i = 0; i < capacity_; i++) {
            if (buckets_[i].occupied) {
                size_t idx = hash_key(buckets_[i].key) & (newCap - 1);
                while (newBuckets[idx].occupied) {
                    idx = (idx + 1) & (newCap - 1);
                }
                newBuckets[idx].key = buckets_[i].key;
                newBuckets[idx].value = buckets_[i].value;
                newBuckets[idx].occupied = true;
            }
        }
        buckets_ = newBuckets;
        capacity_ = newCap;
    }

public:
    unordered_map() : buckets_(nullptr), capacity_(0), size_(0) {}

    size_t size() const { return size_; }
    bool empty() const { return size_ == 0; }

    V& operator[](const K& key) {
        if (capacity_ == 0 || size_ * 4 >= capacity_ * 3) grow();

        size_t idx = hash_key(key) & (capacity_ - 1);
        size_t start = idx;
        size_t firstDeleted = capacity_; // sentinel

        while (true) {
            if (!buckets_[idx].occupied && !buckets_[idx].deleted) {
                // Empty slot — insert here (or at earlier deleted slot)
                size_t insertIdx = (firstDeleted < capacity_) ? firstDeleted : idx;
                buckets_[insertIdx].key = key;
                buckets_[insertIdx].value = V();
                buckets_[insertIdx].occupied = true;
                buckets_[insertIdx].deleted = false;
                size_++;
                return buckets_[insertIdx].value;
            }
            if (buckets_[idx].occupied && buckets_[idx].key == key) {
                return buckets_[idx].value;
            }
            if (buckets_[idx].deleted && firstDeleted == capacity_) {
                firstDeleted = idx;
            }
            idx = (idx + 1) & (capacity_ - 1);
            if (idx == start) {
                // Table full — grow
                grow();
                return operator[](key);
            }
        }
    }

    // Iterator type for range-for
    struct iterator {
        Entry* entries;
        size_t index;
        size_t cap;

        void advance() {
            while (index < cap && !entries[index].occupied) index++;
        }

        pair<const K&, V&> operator*() {
            return pair<const K&, V&>(entries[index].key, entries[index].value);
        }

        // Pointer-like access for structured bindings
        K& first() { return entries[index].key; }
        V& second() { return entries[index].value; }

        iterator& operator++() { index++; advance(); return *this; }
        bool operator!=(const iterator& o) const { return index != o.index; }
    };

    iterator begin() {
        iterator it = { buckets_, 0, capacity_ };
        it.advance();
        return it;
    }

    iterator end() {
        return { buckets_, capacity_, capacity_ };
    }

    size_t count(const K& key) const {
        if (capacity_ == 0) return 0;
        size_t idx = hash_key(key) & (capacity_ - 1);
        size_t start = idx;
        while (true) {
            if (!buckets_[idx].occupied && !buckets_[idx].deleted) return 0;
            if (buckets_[idx].occupied && buckets_[idx].key == key) return 1;
            idx = (idx + 1) & (capacity_ - 1);
            if (idx == start) return 0;
        }
    }

    iterator find(const K& key) {
        if (capacity_ == 0) return end();
        size_t idx = hash_key(key) & (capacity_ - 1);
        size_t start = idx;
        while (true) {
            if (!buckets_[idx].occupied && !buckets_[idx].deleted) return end();
            if (buckets_[idx].occupied && buckets_[idx].key == key) {
                return { buckets_, idx, capacity_ };
            }
            idx = (idx + 1) & (capacity_ - 1);
            if (idx == start) return end();
        }
    }

    void erase(const K& key) {
        if (capacity_ == 0) return;
        size_t idx = hash_key(key) & (capacity_ - 1);
        size_t start = idx;
        while (true) {
            if (!buckets_[idx].occupied && !buckets_[idx].deleted) return;
            if (buckets_[idx].occupied && buckets_[idx].key == key) {
                buckets_[idx].occupied = false;
                buckets_[idx].deleted = true;
                size_--;
                return;
            }
            idx = (idx + 1) & (capacity_ - 1);
            if (idx == start) return;
        }
    }

    void clear() {
        for (size_t i = 0; i < capacity_; i++) {
            buckets_[i].occupied = false;
            buckets_[i].deleted = false;
        }
        size_ = 0;
    }
};

// ============================================================================
// std::function<R(Args...)> — Type-erased callable wrapper
// ============================================================================
// Supports function pointers and lambdas (with small captures).
// Uses bump-allocated memory for captured state.
// ============================================================================
template<class T> class function; // Primary template

template<class R, class... Args>
class function<R(Args...)> {
    // Base interface for type-erased call
    struct ICallable {
        virtual R call(Args... args) = 0;
        virtual ICallable* clone() = 0;
        virtual ~ICallable() {}
    };

    // For plain function pointers
    template<class F>
    struct Callable : ICallable {
        F func;
        Callable(const F& f) : func(f) {}
        R call(Args... args) override { return func(static_cast<Args&&>(args)...); }
        ICallable* clone() override {
            void* mem = flux_heap_alloc(sizeof(Callable<F>));
            return new(mem) Callable<F>(func);
        }
    };

    ICallable* callable_;

public:
    function() : callable_(nullptr) {}

    template<class F>
    function(const F& f) {
        void* mem = flux_heap_alloc(sizeof(Callable<F>));
        callable_ = new(mem) Callable<F>(f);
    }

    function(const function& o) : callable_(nullptr) {
        if (o.callable_) callable_ = o.callable_->clone();
    }

    function& operator=(const function& o) {
        if (o.callable_) callable_ = o.callable_->clone();
        else callable_ = nullptr;
        return *this;
    }

    R operator()(Args... args) const {
        if (callable_) return callable_->call(static_cast<Args&&>(args)...);
        // Should not happen — panic
        return R();
    }

    explicit operator bool() const { return callable_ != nullptr; }
};

// ============================================================================
// std::set<T> — Simple sorted array (small usage in interpreter)
// ============================================================================
template<class T>
class set {
    T* items_;
    size_t size_;
    size_t cap_;

    void grow() {
        size_t newCap = cap_ * 2;
        if (newCap < 8) newCap = 8;
        T* newItems = (T*)flux_heap_alloc(sizeof(T) * newCap);
        if (items_ && size_ > 0) {
            memcpy(newItems, items_, sizeof(T) * size_);
        }
        items_ = newItems;
        cap_ = newCap;
    }

public:
    set() : items_(nullptr), size_(0), cap_(0) {}

    size_t size() const { return size_; }

    size_t count(const T& val) const {
        for (size_t i = 0; i < size_; i++) {
            if (items_[i] == val) return 1;
        }
        return 0;
    }

    void insert(const T& val) {
        if (count(val)) return;
        if (size_ >= cap_) grow();
        items_[size_++] = val;
    }

    void erase(const T& val) {
        for (size_t i = 0; i < size_; i++) {
            if (items_[i] == val) {
                for (size_t j = i; j + 1 < size_; j++) items_[j] = items_[j+1];
                size_--;
                return;
            }
        }
    }
};

// ============================================================================
// std::ostringstream — Stub using FluxString
// ============================================================================
class ostringstream {
    FluxString buf_;
public:
    ostringstream() : buf_("") {}

    ostringstream& operator<<(const char* s) {
        buf_ = buf_ + FluxString(s);
        return *this;
    }

    ostringstream& operator<<(const FluxString& s) {
        buf_ = buf_ + s;
        return *this;
    }

    ostringstream& operator<<(int v) {
        char tmp[16];
        int len = 0;
        if (v == 0) { tmp[len++] = '0'; }
        else {
            bool neg = v < 0;
            if (neg) v = -v;
            while (v > 0 && len < 15) {
                tmp[len++] = '0' + (v % 10);
                v /= 10;
            }
            if (neg && len < 15) tmp[len++] = '-';
            // Reverse
            for (int i = 0; i < len / 2; i++) {
                char t = tmp[i]; tmp[i] = tmp[len-1-i]; tmp[len-1-i] = t;
            }
        }
        tmp[len] = '\0';
        buf_ = buf_ + FluxString(tmp);
        return *this;
    }

    ostringstream& operator<<(double v) {
        // Simple float-to-string (6 decimal places)
        char tmp[32];
        int idx = 0;
        if (v < 0) { tmp[idx++] = '-'; v = -v; }
        int whole = (int)v;
        int frac = (int)((v - whole) * 1000000);
        // Write whole part
        if (whole == 0) { tmp[idx++] = '0'; }
        else {
            char digits[16]; int dc = 0;
            while (whole > 0) { digits[dc++] = '0' + (whole % 10); whole /= 10; }
            for (int i = dc - 1; i >= 0; i--) tmp[idx++] = digits[i];
        }
        tmp[idx++] = '.';
        // Write frac part (6 digits, zero-padded)
        for (int i = 5; i >= 0; i--) {
            int d = 1;
            for (int j = 0; j < i; j++) d *= 10;
            tmp[idx++] = '0' + (frac / d) % 10;
        }
        tmp[idx] = '\0';
        buf_ = buf_ + FluxString(tmp);
        return *this;
    }

    FluxString str() const { return buf_; }
};

// ============================================================================
// std::runtime_error — No-throw error container
// ============================================================================
class runtime_error {
    FluxString msg_;
public:
    runtime_error(const FluxString& m) : msg_(m) {}
    runtime_error(const char* m) : msg_(m) {}
    const FluxString& what() const { return msg_; }
};

// ============================================================================
// Utility: std::to_string
// ============================================================================
inline FluxString to_string(int v) {
    char buf[16];
    int len = 0;
    if (v == 0) { buf[len++] = '0'; }
    else {
        bool neg = v < 0;
        if (neg) v = -v;
        while (v > 0 && len < 15) { buf[len++] = '0' + (v % 10); v /= 10; }
        if (neg) buf[len++] = '-';
        for (int i = 0; i < len/2; i++) {
            char t = buf[i]; buf[i] = buf[len-1-i]; buf[len-1-i] = t;
        }
    }
    buf[len] = '\0';
    return FluxString(buf);
}

inline FluxString to_string(int64_t v) {
    char buf[24];
    int len = 0;
    if (v == 0) { buf[len++] = '0'; }
    else {
        bool neg = v < 0;
        if (neg) v = -v;
        while (v > 0 && len < 23) { buf[len++] = '0' + (char)(v % 10); v /= 10; }
        if (neg) buf[len++] = '-';
        for (int i = 0; i < len/2; i++) {
            char t = buf[i]; buf[i] = buf[len-1-i]; buf[len-1-i] = t;
        }
    }
    buf[len] = '\0';
    return FluxString(buf);
}

inline FluxString to_string(double v) {
    ostringstream ss;
    ss << v;
    return ss.str();
}

inline int stoi(const FluxString& s) {
    int result = 0;
    bool neg = false;
    size_t i = 0;
    if (s.len > 0 && s.data[0] == '-') { neg = true; i = 1; }
    for (; i < s.len; i++) {
        if (s.data[i] >= '0' && s.data[i] <= '9')
            result = result * 10 + (s.data[i] - '0');
    }
    return neg ? -result : result;
}

inline int64_t stoll(const FluxString& s) {
    int64_t result = 0;
    bool neg = false;
    size_t i = 0;
    if (s.len > 0 && s.data[0] == '-') { neg = true; i = 1; }
    for (; i < s.len; i++) {
        if (s.data[i] >= '0' && s.data[i] <= '9')
            result = result * 10 + (s.data[i] - '0');
    }
    return neg ? -result : result;
}

inline double stod(const FluxString& s) {
    double result = 0.0;
    double frac = 0.0;
    double div = 1.0;
    bool neg = false;
    bool inFrac = false;
    size_t i = 0;
    if (s.len > 0 && s.data[0] == '-') { neg = true; i = 1; }
    for (; i < s.len; i++) {
        if (s.data[i] == '.') { inFrac = true; continue; }
        if (s.data[i] >= '0' && s.data[i] <= '9') {
            if (inFrac) { frac = frac * 10 + (s.data[i] - '0'); div *= 10; }
            else { result = result * 10 + (s.data[i] - '0'); }
        }
    }
    result += frac / div;
    return neg ? -result : result;
}

// ============================================================================
// std::move / std::forward (minimal)
// ============================================================================
template<class T>
T&& move(T& v) { return static_cast<T&&>(v); }

template<class T>
T&& forward(T& v) { return static_cast<T&&>(v); }

// ============================================================================
// std::swap
// ============================================================================
template<class T>
void swap(T& a, T& b) {
    T tmp = a; a = b; b = tmp;
}

// ============================================================================
// std::sort (selection sort — simple, no allocator needed)
// ============================================================================
template<class Iter, class Compare>
void sort(Iter begin, Iter end, Compare comp) {
    for (Iter i = begin; i != end; ++i) {
        Iter minIt = i;
        for (Iter j = i; j != end; ++j) {
            if (comp(*j, *minIt)) minIt = j;
        }
        if (minIt != i) {
            auto tmp = *i; *i = *minIt; *minIt = tmp;
        }
    }
}

template<class Iter>
void sort(Iter begin, Iter end) {
    for (Iter i = begin; i != end; ++i) {
        Iter minIt = i;
        for (Iter j = i; j != end; ++j) {
            if (*j < *minIt) minIt = j;
        }
        if (minIt != i) {
            auto tmp = *i; *i = *minIt; *minIt = tmp;
        }
    }
}

// ============================================================================
// std::reverse
// ============================================================================
template<class Iter>
void reverse(Iter begin, Iter end) {
    while (begin != end) {
        --end;
        if (begin == end) break;
        auto tmp = *begin; *begin = *end; *end = tmp;
        ++begin;
    }
}

// ============================================================================
// std::numeric_limits<double> (stub)
// ============================================================================
template<class T> struct numeric_limits {};
template<> struct numeric_limits<double> {
    static double infinity() {
        // IEEE 754 infinity
        union { uint64_t i; double d; } u;
        u.i = 0x7FF0000000000000ULL;
        return u.d;
    }
};

// ============================================================================
// Algorithm helpers
// ============================================================================
inline bool isupper(char c) { return c >= 'A' && c <= 'Z'; }
inline bool islower(char c) { return c >= 'a' && c <= 'z'; }
inline bool isdigit(char c) { return c >= '0' && c <= '9'; }
inline bool isalpha(char c) { return isupper(c) || islower(c) || c == '_'; }
inline bool isalnum(char c) { return isalpha(c) || isdigit(c); }
inline char toupper(char c) { return islower(c) ? c - 32 : c; }
inline char tolower(char c) { return isupper(c) ? c + 32 : c; }

} // namespace std

// ============================================================================
// Hash specialization for FluxString (must be after FluxString is defined)
// ============================================================================
// FluxString IS std::string in freestanding mode, so this provides hashing
// for map keys.
namespace std {
template<> struct hash<FluxString> {
    size_t operator()(const FluxString& s) const {
        return hash_string(s.data, s.len);
    }
};
}

#endif // KSTD_H — note: using pragma once, not include guards
