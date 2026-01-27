using System;

namespace Dummy.Tests;

public class UnitTests
{
    [Fact]
    public void AlwaysSuccessfulTest()
    {
        // Arrange
        TestContext.Current.SendDiagnosticMessage("Starting always successful test...");

        // Act
        var result = true; // Simulating a successful operation

        // Assert
        Assert.True(result, "This test should always succeed.");
    }
}
