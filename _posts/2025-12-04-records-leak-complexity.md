---
layout: post
title: Records leak complexity
---

I was talking to a coworker the other day who described to me how they approached writing code. Their approach goes like this: they put data into _record classes_--classes with just getter/setters and no methods-- and put behavior into either service classes--classes with _only_ behavior and no data--or extension methods--methods on an object that live outside the class itself.

If they had to write their own GitHub clone, their `GitRepository` code could look something like this:

```ruby
class GitRepository
  attr_accessor(:owner, :name, :file_path, :pull_requests, :users_with_access)
end

class GitRepositoryService
  def merge_pr(repo, pr)
    # ...
  end

  def clone(repo)
    # ...
  end

  def give_user_access(repo, user)
    # ...
  end

  def delete(repo)
    # ...
  end
end

module GitRepositoryExtensions
  def clone_url
    # ...
  end
end

# Ruby doesn't have extension methods, but including a module is close enough!
GitRepository.include(GitRepositoryExtensions)
```

Let me start by saying I don't think this code is terrible or anything. It's fine! But I think this approach leads to code that, unless you're very disciplined, sets you up for failure when contrasted to object-orientated programming. OOP emphasizes that instead of exposing state, you hide it and give your users an API--through methods--to interact with that state. Here we do have those methods to interact with our state, but our state is exposed too!  Consider this code:

```ruby
def process_git_clone_request(git_url)
  repo = GitRepository.find(git_url)

  return stream_git_folder_to_client(repo.file_path)
end
```

Seems fine, right? Wrong! You forgot to take into account if the user has access to clone this repository. You should have used `GitRepositoryServer#clone` which checks that. But because you've directly exposed `file_path`, now people who use `GitRepository` have to just know more things about it. You've increased complexity! Instead, by using an object-orientated approach, you could hide `file_path` and therefore spare your users from having to know the rules it has to abide by.

Your domain, just like this git repository, has state, rules that that state has to follow, and structured ways to interact with that state. And if you expose all of your state, you push a huge burden of knowledge on the users of your code. Don't expose state. Hide it!

