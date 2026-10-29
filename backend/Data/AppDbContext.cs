using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
}
