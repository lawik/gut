defmodule GutWeb.SurveyComponentsTest do
  use ExUnit.Case, async: true

  import GutWeb.SurveyComponents, only: [render_markdown: 1]

  describe "render_markdown/1" do
    test "keeps single line breaks from textarea input" do
      html = render_markdown("First line\nSecond line")
      assert html =~ "First line<br>\nSecond line"
    end

    test "separates paragraphs on blank lines" do
      html = render_markdown("One\n\nTwo")
      assert html =~ "<p>One</p>"
      assert html =~ "<p>Two</p>"
    end

    test "supports basic markdown" do
      html = render_markdown("**bold** and _italic_\n\n- a\n- b\n\n[site](https://goatmire.com)")
      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"
      assert html =~ "<li>a</li>"
      assert html =~ ~s(<a href="https://goatmire.com")
    end

    test "neutralises raw html and scripts" do
      html = render_markdown("Hi <script>alert(1)</script><b onclick=\"x()\">there</b>")
      refute html =~ "<script"
      refute html =~ "<b onclick"
      assert html =~ "Hi"
    end

    test "handles nil" do
      assert render_markdown(nil) == ""
    end
  end
end
